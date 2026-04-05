import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../models/device.dart';
import '../models/dose_log.dart';
import '../utils/calculations.dart';

class ExportService {
  ExportService._();
  static final instance = ExportService._();

  // ── CSV ───────────────────────────────────────────────────────

  Future<void> exportCsv(List<Device> devices, List<DoseLog> logs) async {
    final buf = StringBuffer();
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

    buf.writeln('PEPTIDETRACK EXPORT — ${DateFormat('yyyy-MM-dd').format(DateTime.now())}');
    buf.writeln();
    buf.writeln('--- DEVICES ---');
    buf.writeln('ID,Name,Type,Vendor,Batch,Peptide (mg),Recon Vol (mL),Dose (mcg),Dose (IU),Total,Remaining,Schedule,NFC,Enrolled');

    for (final d in devices) {
      buf.writeln([
        _esc(d.id), _esc(d.name), d.type.name, _esc(d.vendor),
        _esc(d.batchNumber), d.peptideMg, d.reconVolumeMl,
        d.desiredDoseMcg, d.doseVolumeIu, d.totalDoses, d.remainingDoses,
        _esc(d.schedule.label), d.nfcTagId != null ? 'Yes' : 'No',
        formatDate(d.createdAt),
      ].join(','));
    }

    buf.writeln();
    buf.writeln('--- DOSE LOGS ---');
    buf.writeln('Log ID,Device ID,Device Name,Logged At,Method,Dose (mcg),Dose (IU)');

    for (final l in logs) {
      final device = devices.where((d) => d.id == l.deviceId).firstOrNull;
      buf.writeln([
        _esc(l.id), _esc(l.deviceId), _esc(device?.name ?? ''),
        DateFormat('yyyy-MM-dd HH:mm:ss').format(l.loggedAt),
        l.method.name, l.doseMcg, l.doseIu,
      ].join(','));
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/PeptideTrack_$stamp.csv');
    await file.writeAsString(buf.toString());
    await Share.shareXFiles([XFile(file.path)], text: 'PeptideTrack data export');
  }

  String _esc(String s) {
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  // ── PDF ───────────────────────────────────────────────────────

  Future<void> exportPdf(List<Device> devices, List<DoseLog> logs) async {
    final pdf = pw.Document();
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final dateStr = DateFormat('MMMM d, yyyy').format(DateTime.now());

    final teal = PdfColor.fromHex('#1D9E75');
    final tealLight = PdfColor.fromHex('#E1F5EE');
    final textSec = PdfColor.fromHex('#6B6B6B');

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (ctx) => [
        // Header
        pw.Text('PeptideTrack Report',
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: teal)),
        pw.SizedBox(height: 6),
        pw.Text('Generated $dateStr · ${devices.length} containers · ${logs.length} dose logs',
          style: pw.TextStyle(fontSize: 12, color: textSec)),
        pw.SizedBox(height: 28),

        // Devices table
        pw.Text('Registered Containers',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(2.5),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(1.5),
            4: const pw.FlexColumnWidth(1.5),
            5: const pw.FlexColumnWidth(1.5),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: tealLight),
              children: ['Name','Type','Vendor','Dose','Remaining','Schedule']
                .map((h) => pw.Padding(
                  padding: const pw.EdgeInsets.all(7),
                  child: pw.Text(h, style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, fontSize: 10, color: teal)),
                )).toList(),
            ),
            ...devices.map((d) => pw.TableRow(
              children: [
                d.name,
                d.type.name,
                d.vendor,
                '${d.desiredDoseMcg.toStringAsFixed(0)}mcg / ${d.doseVolumeIu.toStringAsFixed(0)}IU',
                '${d.remainingDoses}/${d.totalDoses}',
                d.schedule.label,
              ].map((v) => pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(v, style: const pw.TextStyle(fontSize: 9)),
              )).toList(),
            )),
          ],
        ),
        pw.SizedBox(height: 28),

        // Logs table
        pw.Text('Dose History${logs.length > 200 ? ' (latest 200)' : ''}',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(1.5),
            2: const pw.FlexColumnWidth(1.2),
            3: const pw.FlexColumnWidth(1),
            4: const pw.FlexColumnWidth(1.2),
            5: const pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: tealLight),
              children: ['Compound','Date','Time','Method','Dose mcg','Dose IU']
                .map((h) => pw.Padding(
                  padding: const pw.EdgeInsets.all(7),
                  child: pw.Text(h, style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, fontSize: 10, color: teal)),
                )).toList(),
            ),
            ...logs.take(200).map((l) {
              final device = devices.where((d) => d.id == l.deviceId).firstOrNull;
              return pw.TableRow(children: [
                device?.name ?? '—',
                DateFormat('MMM d, yyyy').format(l.loggedAt),
                DateFormat('h:mm a').format(l.loggedAt),
                l.method.name,
                l.doseMcg.toStringAsFixed(0),
                l.doseIu.toStringAsFixed(0),
              ].map((v) => pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(v, style: const pw.TextStyle(fontSize: 9)),
              )).toList());
            }),
          ],
        ),
      ],
    ));

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/PeptideTrack_$stamp.pdf');
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: 'PeptideTrack report');
  }
}
