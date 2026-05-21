import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/device.dart';
import '../models/dose_log.dart';
import '../models/protocol.dart';

class DatabaseService {
  DatabaseService._();
  static final instance = DatabaseService._();

  Database? _db;
  Database get db {
    assert(_db != null, 'Call init() before using DatabaseService');
    return _db!;
  }

  Future<void> init() async {
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      join(dbPath, 'peptidetrack.db'),
      version: 8,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE devices (
        id TEXT PRIMARY KEY NOT NULL,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        vendor TEXT NOT NULL,
        batch_number TEXT NOT NULL,
        coa_url TEXT,
        reconstitution_date TEXT NOT NULL,
        peptide_mg REAL NOT NULL,
        recon_volume_ml REAL NOT NULL,
        desired_dose_mcg REAL NOT NULL,
        dose_volume_iu REAL NOT NULL,
        total_doses INTEGER NOT NULL,
        remaining_doses INTEGER NOT NULL,
        schedule TEXT NOT NULL,
        schedule_days TEXT,
        expiry_days INTEGER NOT NULL DEFAULT 30,
        schedule_start_date TEXT,
        is_blend INTEGER NOT NULL DEFAULT 0,
        blend_components_json TEXT,
        nfc_tag_id TEXT,
        nfc_mode TEXT NOT NULL DEFAULT 'tag',
        alert_threshold_pct INTEGER NOT NULL DEFAULT 10,
        notification_id TEXT,
        active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE dose_logs (
        id TEXT PRIMARY KEY NOT NULL,
        device_id TEXT NOT NULL,
        logged_at TEXT NOT NULL,
        method TEXT NOT NULL,
        dose_mcg REAL NOT NULL,
        dose_iu REAL NOT NULL,
        notes TEXT,
        injection_site TEXT,
        FOREIGN KEY (device_id) REFERENCES devices(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE protocols (
        id TEXT PRIMARY KEY NOT NULL,
        name TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE protocol_devices (
        protocol_id TEXT NOT NULL,
        device_id TEXT NOT NULL,
        PRIMARY KEY (protocol_id, device_id),
        FOREIGN KEY (protocol_id) REFERENCES protocols(id),
        FOREIGN KEY (device_id) REFERENCES devices(id)
      )
    ''');

    await db.execute('CREATE INDEX idx_logs_device ON dose_logs(device_id)');
    await db.execute('CREATE INDEX idx_logs_date ON dose_logs(logged_at)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE dose_logs ADD COLUMN injection_site TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE devices ADD COLUMN schedule_days TEXT');
    }
    if (oldVersion < 5) {
      await db.execute(
          'ALTER TABLE devices ADD COLUMN expiry_days INTEGER NOT NULL DEFAULT 30');
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS protocols (
          id TEXT PRIMARY KEY NOT NULL,
          name TEXT NOT NULL,
          start_date TEXT NOT NULL,
          end_date TEXT,
          notes TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS protocol_devices (
          protocol_id TEXT NOT NULL,
          device_id TEXT NOT NULL,
          PRIMARY KEY (protocol_id, device_id),
          FOREIGN KEY (protocol_id) REFERENCES protocols(id),
          FOREIGN KEY (device_id) REFERENCES devices(id)
        )
      ''');
    }
    if (oldVersion < 6) {
      await db.execute(
          'ALTER TABLE devices ADD COLUMN is_blend INTEGER NOT NULL DEFAULT 0');
      await db
          .execute('ALTER TABLE devices ADD COLUMN blend_components_json TEXT');
    }
    if (oldVersion < 7) {
      await db
          .execute('ALTER TABLE devices ADD COLUMN schedule_start_date TEXT');
    }
    if (oldVersion < 8) {
      await db.execute(
          "ALTER TABLE devices ADD COLUMN nfc_mode TEXT NOT NULL DEFAULT 'tag'");
    }
  }

  // ── Devices ──────────────────────────────────────────────────

  Future<List<Device>> getAllDevices() async {
    final rows = await db.query('devices', orderBy: 'created_at DESC');
    return rows.map(Device.fromMap).toList();
  }

  Future<Device?> getDeviceByNfcTagId(String nfcTagId) async {
    final rows = await db.query(
      'devices',
      where: 'nfc_tag_id = ? AND active = 1',
      whereArgs: [nfcTagId],
      limit: 1,
    );
    return rows.isEmpty ? null : Device.fromMap(rows.first);
  }

  Future<Device?> getConflictingDeviceByNfcTagId(String nfcTagId) async {
    final rows = await db.query(
      'devices',
      where: 'nfc_tag_id = ? AND active = 1 AND remaining_doses > 0',
      whereArgs: [nfcTagId],
      limit: 1,
    );
    return rows.isEmpty ? null : Device.fromMap(rows.first);
  }

  Future<void> insertDevice(Device device) async {
    await db.insert('devices', device.toMap());
  }

  Future<void> updateDevice(Device device) async {
    await db.update('devices', device.toMap(),
        where: 'id = ?', whereArgs: [device.id]);
  }

  Future<void> updateRemainingDoses(String deviceId, int remaining) async {
    await db.update(
      'devices',
      {'remaining_doses': remaining},
      where: 'id = ?',
      whereArgs: [deviceId],
    );
  }

  Future<void> deactivateDevice(String deviceId) async {
    await db.update('devices', {'active': 0, 'remaining_doses': 0},
        where: 'id = ?', whereArgs: [deviceId]);
  }

  Future<void> deleteAllDevices() async => db.delete('devices');

  // ── Dose logs ─────────────────────────────────────────────────

  Future<List<DoseLog>> getAllDoseLogs() async {
    final rows = await db.query('dose_logs', orderBy: 'logged_at DESC');
    return rows.map(DoseLog.fromMap).toList();
  }

  Future<List<DoseLog>> getLogsForDevice(String deviceId) async {
    final rows = await db.query(
      'dose_logs',
      where: 'device_id = ?',
      whereArgs: [deviceId],
      orderBy: 'logged_at DESC',
    );
    return rows.map(DoseLog.fromMap).toList();
  }

  Future<void> insertDoseLog(DoseLog log) async {
    await db.insert('dose_logs', log.toMap());
  }

  Future<void> updateDoseLog(DoseLog log) async {
    await db
        .update('dose_logs', log.toMap(), where: 'id = ?', whereArgs: [log.id]);
  }

  Future<void> deleteDoseLog(String logId) async {
    await db.delete('dose_logs', where: 'id = ?', whereArgs: [logId]);
  }

  Future<void> deleteAllLogs() async => db.delete('dose_logs');

  // ── Protocols ─────────────────────────────────────────────────

  Future<List<Protocol>> getAllProtocols() async {
    final rows = await db.query('protocols', orderBy: 'start_date DESC');
    return rows.map(Protocol.fromMap).toList();
  }

  Future<void> insertProtocol(Protocol protocol) async {
    await db.insert('protocols', protocol.toMap());
  }

  Future<void> updateProtocol(Protocol protocol) async {
    await db.update('protocols', protocol.toMap(),
        where: 'id = ?', whereArgs: [protocol.id]);
  }

  Future<void> deleteProtocol(String protocolId) async {
    await db.delete('protocol_devices',
        where: 'protocol_id = ?', whereArgs: [protocolId]);
    await db.delete('protocols', where: 'id = ?', whereArgs: [protocolId]);
  }

  Future<Map<String, String>> getDeviceProtocolMap() async {
    final rows = await db.query('protocol_devices');
    return {
      for (final r in rows) r['device_id'] as String: r['protocol_id'] as String
    };
  }

  Future<void> setDevicesForProtocol(
      String protocolId, List<String> deviceIds) async {
    await db.delete('protocol_devices',
        where: 'protocol_id = ?', whereArgs: [protocolId]);
    for (final deviceId in deviceIds) {
      await db.insert(
          'protocol_devices',
          {
            'protocol_id': protocolId,
            'device_id': deviceId,
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> removeDeviceFromAllProtocols(String deviceId) async {
    await db.delete('protocol_devices',
        where: 'device_id = ?', whereArgs: [deviceId]);
  }

  // ── Clear all ─────────────────────────────────────────────────

  Future<void> clearAllData() async {
    await db.delete('protocol_devices');
    await db.delete('protocols');
    await db.delete('dose_logs');
    await db.delete('devices');
  }
}
