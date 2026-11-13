import CoreNFC
import Foundation

enum NovoPenProtocolError: Error {
  case notIso7816
  case apduFailed(UInt16)
  case invalidData(String)
}

private final class ByteReader {
  private let bytes: [UInt8]
  private var index: Int = 0

  init(_ data: Data) {
    self.bytes = [UInt8](data)
  }

  init(_ bytes: [UInt8]) {
    self.bytes = bytes
  }

  var remaining: Int { bytes.count - index }
  var hasRemaining: Bool { remaining > 0 }

  func readByte() throws -> UInt8 {
    guard index < bytes.count else { throw NovoPenProtocolError.invalidData("EOF") }
    let b = bytes[index]
    index += 1
    return b
  }

  func readBytes(_ count: Int) throws -> [UInt8] {
    guard count >= 0, index + count <= bytes.count else {
      throw NovoPenProtocolError.invalidData("Out of bounds read")
    }
    let out = Array(bytes[index..<(index + count)])
    index += count
    return out
  }

  func readUInt16() throws -> Int {
    let hi = Int(try readByte())
    let lo = Int(try readByte())
    return (hi << 8) | lo
  }

  func readInt32() throws -> Int {
    let b0 = Int(try readByte())
    let b1 = Int(try readByte())
    let b2 = Int(try readByte())
    let b3 = Int(try readByte())
    return Int(Int32(bitPattern: UInt32((b0 << 24) | (b1 << 16) | (b2 << 8) | b3)))
  }
}

private struct NvpConstants {
  static let cla = 0x00
  static let insSelect = 0xA4
  static let insReadBinary = 0xB0
  static let byName = 0x04
  static let firstOnly = 0x0C

  static let commandCompleted: UInt16 = 0x9000

  static let ndefTagApplicationSelect: [UInt8] = [0xD2, 0x76, 0x00, 0x00, 0x85, 0x01, 0x01]
  static let capabilityContainerSelect: [UInt8] = [0xE1, 0x03]
  static let ndefSelect: [UInt8] = [0xE1, 0x04]
}

private final class Iso7816Transport {
  private let tag: NFCISO7816Tag
  private let timeoutSeconds: Double

  init(tag: NFCISO7816Tag, timeoutSeconds: Double = 2.0) {
    self.tag = tag
    self.timeoutSeconds = timeoutSeconds
  }

  func transceive(_ command: [UInt8]) throws -> [UInt8] {
    guard let apdu = NFCISO7816APDU(data: Data(command)) else {
      throw NovoPenProtocolError.invalidData("Invalid APDU bytes")
    }
    let sem = DispatchSemaphore(value: 0)
    var outData = Data()
    var outStatus: UInt16 = 0
    var outError: Error?
    tag.sendCommand(apdu: apdu) { data, sw1, sw2, error in
      outData = data
      outStatus = (UInt16(sw1) << 8) | UInt16(sw2)
      outError = error
      sem.signal()
    }
    if sem.wait(timeout: .now() + timeoutSeconds) == .timedOut {
      throw NovoPenProtocolError.invalidData("APDU timeout")
    }
    if let outError {
      throw outError
    }
    guard outStatus == NvpConstants.commandCompleted else {
      throw NovoPenProtocolError.apduFailed(outStatus)
    }
    return [UInt8](outData)
  }
}

private struct InsulinDose {
  let relativeTime: Int
  let units: Int
  let flags: Int
}

private struct EventReportData {
  let relativeTime: Int
  let eventType: Int
  let configurationId: Int?
  let invokeInstance: Int
  let invokeIndex: Int
  let doses: [InsulinDose]
}

private final class NovoPenProtocolReader {
  private let io: Iso7816Transport
  private var sequence: Int = 1
  private static let validDoseFlag = 0x08000000

  init(io: Iso7816Transport) {
    self.io = io
  }

  func read() throws -> [String: Any] {
    _ = try readResult(applicationSelect())
    _ = try readResult(capabilityContainerSelect())
    _ = try readResult(readBinary(offset: 0, length: 15))
    _ = try readResult(ndefSelect())

    let lenResult = try readResult(readBinary(offset: 0, length: 2))
    var lenReader = ByteReader(lenResult)
    let ndefLength = try lenReader.readUInt16()
    let fullRead = try readResult(readBinary(offset: 2, length: ndefLength))

    _ = try readResult(updatePayload([0xD0, 0x00, 0x00]))
    let phd = try parsePhdPacket(fullRead)

    let aReq = try parseARequest(phd.content)
    let aRespPayload = buildAResponsePayload(apoepRaw: aReq.apoepRaw)
    let aRespApdu = buildApdu(at: 0xE300, payload: aRespPayload)
    let aRespBytes = try sendPhdRequest(aRespApdu)
    let (invokeId, configId) = try parseConfigurationNotification(aRespBytes)

    let retrieveInfo = buildRetrieveInfoRequest(invokeId: invokeId, configId: configId)
    _ = try sendPhdRequest(retrieveInfo)

    let askInfo = buildAskInformationRequest(invokeId: invokeId)
    let askInfoResp = try sendPhdRequest(askInfo)
    let spec = try parseSpecificationResponse(askInfoResp)

    let actionReq = buildConfirmedActionRequest(invokeId: invokeId)
    let actionResp = try sendPhdRequest(actionReq)
    let segment = try parseSegmentInfo(actionResp)

    let xferReq = buildXferActionRequest(invokeId: invokeId, segmentId: segment)
    _ = try sendPhdRequest(xferReq)
    var next = try sendPhdRequest([])

    var allDoses: [InsulinDose] = []
    var finished = false
    while !finished {
      if next.isEmpty {
        next = try sendPhdRequest([])
      }
      if let (event, respInvokeId) = try parseSegmentDoseEvent(next) {
        allDoses.append(contentsOf: event.doses.filter { $0.flags == Self.validDoseFlag })
        if event.doses.isEmpty {
          finished = true
        } else {
          let req = buildConfirmedXferRequest(
            invokeId: respInvokeId,
            instance: event.invokeInstance,
            index: event.invokeIndex,
            count: event.doses.count
          )
          next = try sendPhdRequest(req)
        }
      } else {
        finished = true
      }
    }

    let nowMs = Int64(Date().timeIntervalSince1970 * 1000.0)
    let doses = allDoses.enumerated().map { idx, d -> [String: Any] in
      let utcMs = nowMs - Int64((spec.relativeTime - d.relativeTime) * 1000)
      return [
        "index": idx,
        "timeMs": utcMs,
        "units": d.units,
        "flags": d.flags,
      ]
    }
    return [
      "model": spec.model,
      "serial": spec.serial,
      "startTime": spec.relativeTime,
      "doses": doses,
    ]
  }

  private func sendPhdRequest(_ content: [UInt8]) throws -> [UInt8] {
    let phd = buildPhdPacket(content: content)
    _ = try readResult(updatePayload(phd))

    let lenResult = try readResult(readBinary(offset: 0, length: 2))
    var lenReader = ByteReader(lenResult)
    let len = try lenReader.readUInt16()

    var full: [UInt8] = []
    var offset = 2
    var left = len
    while left > 0 {
      let chunk = min(255, left)
      full += try readResult(readBinary(offset: offset, length: chunk))
      offset += chunk
      left -= chunk
    }
    let resultPhd = try parsePhdPacket(full)
    sequence = resultPhd.sequence + 1

    _ = try readResult(updatePayload([0xD0, 0x00, 0x00]))
    return resultPhd.content
  }

  private func readResult(_ cmd: [UInt8]) throws -> [UInt8] {
    return try io.transceive(cmd)
  }

  private func applicationSelect() -> [UInt8] {
    return transceivePayload(p1: NvpConstants.byName, p2: 0, data: NvpConstants.ndefTagApplicationSelect, addLe: true)
  }

  private func capabilityContainerSelect() -> [UInt8] {
    return transceivePayload(p1: 0, p2: NvpConstants.firstOnly, data: NvpConstants.capabilityContainerSelect, addLe: false)
  }

  private func ndefSelect() -> [UInt8] {
    return transceivePayload(p1: 0, p2: NvpConstants.firstOnly, data: NvpConstants.ndefSelect, addLe: false)
  }

  private func transceivePayload(p1: Int, p2: Int, data: [UInt8], addLe: Bool) -> [UInt8] {
    var out: [UInt8] = [UInt8(NvpConstants.cla), UInt8(NvpConstants.insSelect), UInt8(p1), UInt8(p2), UInt8(data.count)]
    out += data
    if addLe { out.append(0x00) }
    return out
  }

  private func readBinary(offset: Int, length: Int) -> [UInt8] {
    return [
      UInt8(NvpConstants.cla),
      UInt8(NvpConstants.insReadBinary),
      UInt8((offset >> 8) & 0xFF),
      UInt8(offset & 0xFF),
      UInt8(length & 0xFF),
    ]
  }

  private func updatePayload(_ data: [UInt8]) -> [UInt8] {
    let size = data.count + 2
    var out: [UInt8] = [0x00, 0xD6, 0x00, 0x00, UInt8(size & 0xFF), UInt8((data.count >> 8) & 0xFF), UInt8(data.count & 0xFF)]
    out += data
    return out
  }

  private func buildPhdPacket(content: [UInt8]) -> [UInt8] {
    var out: [UInt8] = [0xD1, 0x03, UInt8((content.count + 1) & 0xFF), 0x50, 0x48, 0x44]
    out.append(UInt8((sequence & 0x0F) | 0x80))
    out += content
    return out
  }

  private struct ParsedPhd {
    let sequence: Int
    let content: [UInt8]
  }

  private func parsePhdPacket(_ bytes: [UInt8]) throws -> ParsedPhd {
    var r = ByteReader(bytes)
    let opcode = try r.readByte()
    _ = try r.readByte()
    let payloadLen = try r.readByte()
    if (opcode & 0x08) != 0 {
      let idLen = Int(try r.readByte())
      _ = try r.readBytes(idLen)
    }
    _ = try r.readBytes(3) // "PHD"
    let chk = Int(try r.readByte())
    let actualLen = min(Int(payloadLen) - 1, r.remaining)
    let content = try r.readBytes(max(0, actualLen))
    return ParsedPhd(sequence: chk & 0x0F, content: content)
  }

  private struct ParsedARequest {
    let apoepRaw: [UInt8]
  }

  private func parseARequest(_ bytes: [UInt8]) throws -> ParsedARequest {
    var r = ByteReader(bytes)
    let at = try r.readUInt16()
    _ = try r.readUInt16()
    guard at == 0xE200 || at == 0xE300 else {
      throw NovoPenProtocolError.invalidData("Unexpected ARequest APDU type")
    }
    _ = try r.readInt32() // version
    let elements = try r.readUInt16()
    _ = try r.readUInt16()
    var apoep: [UInt8] = []
    for _ in 0..<elements {
      let proto = try r.readUInt16()
      let len = try r.readUInt16()
      let payload = try r.readBytes(len)
      if proto == 20601 { apoep = payload }
    }
    guard !apoep.isEmpty else {
      throw NovoPenProtocolError.invalidData("APOEP not found")
    }
    return ParsedARequest(apoepRaw: apoep)
  }

  private func buildAResponsePayload(apoepRaw: [UInt8]) -> [UInt8] {
    var apoep = apoepRaw
    if apoep.count >= 28 {
      // recMode (offset 20..23), configId (18..19), systemType (12..15), listCount/listLen (24..27)
      apoep[12] = 0x80
      apoep[13] = 0x00
      apoep[14] = 0x00
      apoep[15] = 0x00
      apoep[18] = 0x00
      apoep[19] = 0x00
      apoep[20] = 0x00
      apoep[21] = 0x00
      apoep[22] = 0x00
      apoep[23] = 0x00
      apoep[24] = 0x00
      apoep[25] = 0x00
      apoep[26] = 0x00
      apoep[27] = 0x00
    }
    var payload: [UInt8] = [0x00, 0x03, 0x50, 0x79, UInt8((apoep.count >> 8) & 0xFF), UInt8(apoep.count & 0xFF)]
    payload += apoep
    return payload
  }

  private func buildApdu(at: Int, payload: [UInt8]) -> [UInt8] {
    var out: [UInt8] = [
      UInt8((at >> 8) & 0xFF),
      UInt8(at & 0xFF),
      UInt8((payload.count >> 8) & 0xFF),
      UInt8(payload.count & 0xFF),
    ]
    out += payload
    return out
  }

  private func buildDataApdu(invokeId: Int, dchoice: Int, payload: [UInt8]?) -> [UInt8] {
    let payloadLen = payload?.count ?? 0
    let innerLen = 4 + (payload == nil ? 0 : (2 + payloadLen))
    var out: [UInt8] = [
      UInt8((innerLen >> 8) & 0xFF), UInt8(innerLen & 0xFF),
      UInt8((invokeId >> 8) & 0xFF), UInt8(invokeId & 0xFF),
      UInt8((dchoice >> 8) & 0xFF), UInt8(dchoice & 0xFF),
    ]
    if let payload {
      out += [UInt8((payloadLen >> 8) & 0xFF), UInt8(payloadLen & 0xFF)]
      out += payload
    }
    return out
  }

  private func buildRetrieveInfoRequest(invokeId: Int, configId: Int) -> [UInt8] {
    let eventData: [UInt8] = [UInt8((configId >> 8) & 0xFF), UInt8(configId & 0xFF), 0x00, 0x00]
    let event = buildEventRequest(handle: 0, currentTime: 0, type: 3356, data: eventData)
    let dataApdu = buildDataApdu(invokeId: invokeId, dchoice: 0x0201, payload: event)
    return buildApdu(at: 0xE700, payload: dataApdu)
  }

  private func buildAskInformationRequest(invokeId: Int) -> [UInt8] {
    let argsSimple: [UInt8] = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
    let dataApdu = buildDataApdu(invokeId: invokeId, dchoice: 0x0103, payload: argsSimple)
    return buildApdu(at: 0xE700, payload: dataApdu)
  }

  private func buildConfirmedActionRequest(invokeId: Int) -> [UInt8] {
    let actionPayload: [UInt8] = [0x01, 0x00, 0x0C, 0x0D, 0x00, 0x06, 0x00, 0x01, 0x00, 0x02, 0x00, 0x00]
    let dataApdu = buildDataApdu(invokeId: invokeId, dchoice: 0x0107, payload: actionPayload)
    return buildApdu(at: 0xE700, payload: dataApdu)
  }

  private func buildXferActionRequest(invokeId: Int, segmentId: Int) -> [UInt8] {
    let payload: [UInt8] = [0x01, 0x00, 0x0C, 0x1C, 0x00, 0x02, UInt8((segmentId >> 8) & 0xFF), UInt8(segmentId & 0xFF)]
    let dataApdu = buildDataApdu(invokeId: invokeId, dchoice: 0x0107, payload: payload)
    return buildApdu(at: 0xE700, payload: dataApdu)
  }

  private func buildConfirmedXferRequest(invokeId: Int, instance: Int, index: Int, count: Int) -> [UInt8] {
    let reqData: [UInt8] = [
      UInt8((instance >> 8) & 0xFF), UInt8(instance & 0xFF),
      0x00, 0x00,
      UInt8((index >> 8) & 0xFF), UInt8(index & 0xFF),
      0x00, 0x00,
      UInt8((count >> 8) & 0xFF), UInt8(count & 0xFF),
      0x00, 0x80,
    ]
    let event = buildEventRequest(handle: 0x0100, currentTime: -1, type: 3361, data: reqData)
    let dataApdu = buildDataApdu(invokeId: invokeId, dchoice: 0x0201, payload: event)
    return buildApdu(at: 0xE700, payload: dataApdu)
  }

  private func buildEventRequest(handle: Int, currentTime: Int, type: Int, data: [UInt8]) -> [UInt8] {
    var out: [UInt8] = [
      UInt8((handle >> 8) & 0xFF), UInt8(handle & 0xFF),
      UInt8((currentTime >> 24) & 0xFF), UInt8((currentTime >> 16) & 0xFF), UInt8((currentTime >> 8) & 0xFF), UInt8(currentTime & 0xFF),
      UInt8((type >> 8) & 0xFF), UInt8(type & 0xFF),
      UInt8((data.count >> 8) & 0xFF), UInt8(data.count & 0xFF),
    ]
    out += data
    return out
  }

  private func parseConfigurationNotification(_ bytes: [UInt8]) throws -> (invokeId: Int, configId: Int) {
    let data = try parseDataApduFromPhdResponse(bytes)
    guard data.dchoice == 0x0101, let event = data.event else {
      throw NovoPenProtocolError.invalidData("Expected config event")
    }
    guard let cfg = event.configurationId else {
      throw NovoPenProtocolError.invalidData("Configuration ID missing")
    }
    return (data.invokeId, cfg)
  }

  private struct SpecInfo {
    let serial: String
    let model: String
    let relativeTime: Int
  }

  private func parseSpecificationResponse(_ bytes: [UInt8]) throws -> SpecInfo {
    let data = try parseDataApduFromPhdResponse(bytes)
    guard data.dchoice == 0x0103 || data.dchoice == 0x0203 else {
      throw NovoPenProtocolError.invalidData("Expected spec response")
    }
    let attrs = data.attributes
    var serial = ""
    var relativeTime = 0
    var modelParts: [String] = []
    for a in attrs {
      switch a.type {
      case 2349:
        serial = try parseSpecificationSerial(a.data)
      case 2447:
        var r = ByteReader(a.data)
        relativeTime = try r.readInt32()
      case 2344:
        modelParts = try parseIndexedStrings(a.data)
      default:
        break
      }
    }
    return SpecInfo(serial: serial, model: modelParts.joined(separator: " "), relativeTime: relativeTime)
  }

  private func parseSegmentInfo(_ bytes: [UInt8]) throws -> Int {
    let data = try parseDataApduFromPhdResponse(bytes)
    guard data.dchoice == 0x0207 else {
      throw NovoPenProtocolError.invalidData("Expected confirmed action response")
    }
    return data.segmentId
  }

  private func parseSegmentDoseEvent(_ bytes: [UInt8]) throws -> (EventReportData, Int)? {
    guard !bytes.isEmpty else { return nil }
    let data = try parseDataApduFromPhdResponse(bytes)
    guard data.dchoice == 0x0101, let event = data.event, event.eventType == 3361 else {
      return nil
    }
    return (event, data.invokeId)
  }

  private struct ParsedDataApdu {
    let invokeId: Int
    let dchoice: Int
    let event: EventReportData?
    let attributes: [(type: Int, data: [UInt8])]
    let segmentId: Int
  }

  private func parseDataApduFromPhdResponse(_ bytes: [UInt8]) throws -> ParsedDataApdu {
    let phd = try parsePhdPacket(bytes)
    var r = ByteReader(phd.content)
    _ = try r.readUInt16() // at
    _ = try r.readUInt16() // len
    _ = try r.readUInt16() // data apdu olen
    let invokeId = try r.readUInt16()
    let dchoice = try r.readUInt16()
    _ = try r.readUInt16() // dlen

    if dchoice == 0x0101 {
      let event = try parseEventReport(r: r)
      return ParsedDataApdu(invokeId: invokeId, dchoice: dchoice, event: event, attributes: [], segmentId: -1)
    }
    if dchoice == 0x0103 || dchoice == 0x0203 {
      _ = try r.readUInt16() // handle
      let attrCount = try r.readUInt16()
      _ = try r.readUInt16() // len
      var attrs: [(Int, [UInt8])] = []
      for _ in 0..<attrCount {
        let t = try r.readUInt16()
        let l = try r.readUInt16()
        let d = try r.readBytes(l)
        attrs.append((t, d))
      }
      return ParsedDataApdu(invokeId: invokeId, dchoice: dchoice, event: nil, attributes: attrs, segmentId: -1)
    }
    if dchoice == 0x0207 {
      _ = try r.readUInt16() // handle
      let actionType = try r.readUInt16()
      _ = try r.readUInt16() // action len
      if actionType == 0x0C0D {
        let count = try r.readUInt16()
        _ = try r.readUInt16() // len
        guard count > 0 else { throw NovoPenProtocolError.invalidData("No segments") }
        let segmentId = try r.readUInt16()
        return ParsedDataApdu(invokeId: invokeId, dchoice: dchoice, event: nil, attributes: [], segmentId: segmentId)
      }
    }
    return ParsedDataApdu(invokeId: invokeId, dchoice: dchoice, event: nil, attributes: [], segmentId: -1)
  }

  private func parseEventReport(r: ByteReader) throws -> EventReportData {
    _ = try r.readUInt16() // handle
    let relativeTime = try r.readInt32()
    let eventType = try r.readUInt16()
    _ = try r.readUInt16() // len
    if eventType == 3356 {
      let configId = try r.readUInt16()
      return EventReportData(relativeTime: relativeTime, eventType: eventType, configurationId: configId, invokeInstance: -1, invokeIndex: -1, doses: [])
    }
    if eventType == 3361 {
      let instance = try r.readUInt16()
      let index = try r.readInt32()
      let count = try r.readInt32()
      _ = try r.readUInt16() // status
      _ = try r.readUInt16() // bcount
      var doses: [InsulinDose] = []
      for _ in 0..<max(0, count) {
        let t = try r.readInt32()
        let unitsRaw = try r.readInt32()
        let flags = try r.readInt32()
        doses.append(InsulinDose(relativeTime: t, units: unitsRaw & 0xFFFF, flags: flags))
      }
      return EventReportData(relativeTime: relativeTime, eventType: eventType, configurationId: nil, invokeInstance: instance, invokeIndex: index, doses: doses)
    }
    return EventReportData(relativeTime: relativeTime, eventType: eventType, configurationId: nil, invokeInstance: -1, invokeIndex: -1, doses: [])
  }

  private func parseSpecificationSerial(_ bytes: [UInt8]) throws -> String {
    var r = ByteReader(bytes)
    let count = try r.readUInt16()
    _ = try r.readUInt16() // size
    var serial = ""
    for _ in 0..<count {
      let itemType = try r.readUInt16()
      _ = try r.readUInt16() // component
      let s = try readIndexedString(r: r)
      if itemType == 1 { serial = s }
    }
    return serial
  }

  private func parseIndexedStrings(_ bytes: [UInt8]) throws -> [String] {
    var r = ByteReader(bytes)
    var out: [String] = []
    while r.hasRemaining {
      out.append(try readIndexedString(r: r))
    }
    return out
  }

  private func readIndexedString(r: ByteReader) throws -> String {
    let len = try r.readUInt16()
    let raw = try r.readBytes(len)
    let data = Data(raw)
    return String(data: data, encoding: .utf8)?.replacingOccurrences(of: "\0", with: "") ?? ""
  }
}

func readNovoPenPayload(tag: NFCTag) throws -> [String: Any] {
  guard case let .iso7816(isoTag) = tag else {
    throw NovoPenProtocolError.notIso7816
  }
  let transport = Iso7816Transport(tag: isoTag)
  let reader = NovoPenProtocolReader(io: transport)
  return try reader.read()
}
