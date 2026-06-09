import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../repositories/app_database.dart';

class BackupService {
  final AppDatabase appDatabase;

  BackupService({required this.appDatabase});

  /// Exports all tables (grupos, pontos_consumo, historico_leituras) to a JSON file and shares it.
  Future<void> exportBackup() async {
    final db = await appDatabase.database;

    final grupos = await db.query('grupos');
    final pontos = await db.query('pontos_consumo');
    final historico = await db.query('historico_leituras');

    final backupData = {
      'backup_version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'grupos': grupos,
      'pontos_consumo': pontos,
      'historico_leituras': historico,
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(backupData);
    final tempDir = await getTemporaryDirectory();
    final dateStr = DateTime.now()
        .toLocal()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    
    final file = File('${tempDir.path}/backup_leituras_$dateStr.json');
    await file.writeAsString(jsonString);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: 'Backup de Leituras ($dateStr)',
    );
  }

  /// Restores the database from a backup JSON string.
  /// Wipes all existing tables and re-inserts the data with original IDs.
  Future<void> importBackup(String jsonString) async {
    final Map<String, dynamic> backupData = jsonDecode(jsonString);

    final version = backupData['backup_version'] as int?;
    if (version == null) {
      throw const FormatException('Formato de backup inválido: Versão ausente.');
    }

    final grupos = backupData['grupos'] as List?;
    final pontos = backupData['pontos_consumo'] as List?;
    final historico = backupData['historico_leituras'] as List?;

    if (grupos == null || pontos == null || historico == null) {
      throw const FormatException('Dados de backup incompletos.');
    }

    final db = await appDatabase.database;

    await db.transaction((txn) async {
      // Clear all existing data
      await txn.delete('historico_leituras');
      await txn.delete('pontos_consumo');
      await txn.delete('grupos');

      // Import grupos preserving IDs
      for (final g in grupos) {
        final map = Map<String, dynamic>.from(g);
        await txn.insert('grupos', map);
      }

      // Import pontos_consumo preserving IDs
      for (final p in pontos) {
        final map = Map<String, dynamic>.from(p);
        await txn.insert('pontos_consumo', map);
      }

      // Import historico_leituras preserving IDs
      for (final h in historico) {
        final map = Map<String, dynamic>.from(h);
        await txn.insert('historico_leituras', map);
      }
    });
  }
}
