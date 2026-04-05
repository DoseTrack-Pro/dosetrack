import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/device.dart';
import '../models/dose_log.dart';

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
      version: 1,
      onCreate: _onCreate,
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
        nfc_tag_id TEXT,
        alert_threshold_pct INTEGER NOT NULL DEFAULT 20,
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
        FOREIGN KEY (device_id) REFERENCES devices(id)
      )
    ''');

    await db.execute('CREATE INDEX idx_logs_device ON dose_logs(device_id)');
    await db.execute('CREATE INDEX idx_logs_date ON dose_logs(logged_at)');
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

  Future<void> insertDevice(Device device) async {
    await db.insert('devices', device.toMap());
  }

  Future<void> updateDevice(Device device) async {
    await db.update('devices', device.toMap(), where: 'id = ?', whereArgs: [device.id]);
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
    await db.update('devices', {'active': 0}, where: 'id = ?', whereArgs: [deviceId]);
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

  Future<void> deleteAllLogs() async => db.delete('dose_logs');

  Future<void> clearAllData() async {
    await db.delete('dose_logs');
    await db.delete('devices');
  }
}
