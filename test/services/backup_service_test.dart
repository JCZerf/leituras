import 'dart:convert';
import 'dart:ffi';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:leituras/repositories/app_database.dart';
import 'package:leituras/services/backup_service.dart';

void main() {
  late AppDatabase database;
  late BackupService backupService;
  final sqliteAvailable = _isSqliteAvailable();

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() {
    database = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    backupService = BackupService(appDatabase: database);
  });

  tearDown(() async {
    await database.close();
  });

  group('BackupService Import validation tests', () {
    test('throws FormatException when backup_version is missing', () async {
      const invalidBackupJson = '{"grupos": [], "pontos_consumo": [], "historico_leituras": []}';
      expect(
        () => backupService.importBackup(invalidBackupJson),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('Versão ausente'))),
      );
    });

    test('throws FormatException when table lists are missing', () async {
      const invalidBackupJson = '{"backup_version": 1}';
      expect(
        () => backupService.importBackup(invalidBackupJson),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('Dados de backup incompletos'))),
      );
    });
  });

  group('BackupService DB transaction tests', () {
    test(
      'successfully restores data from a valid backup JSON',
      () async {
        final db = await database.database;

        final backupData = {
          'backup_version': 1,
          'exported_at': '2026-06-07T18:00:00Z',
          'grupos': [
            {
              'id': 10,
              'nome': 'Grupo Teste Backup',
              'descricao': 'Grupo Importado',
              'data_criacao': '2026-06-07 18:00:00',
            }
          ],
          'pontos_consumo': [
            {
              'id': 20,
              'grupo_id': 10,
              'instalacao': '1234567890',
              'numero_medidor': '12345678901',
              'endereco': 'Rua de Teste, 123',
              'is_interno': 1,
            }
          ],
          'historico_leituras': [
            {
              'id': 30,
              'ponto_consumo_id': 20,
              'valor_leitura': 4321,
              'data_leitura': '2026-06-07 18:15:00',
              'foto_path': null,
              'foto_descricao': 'Teste',
            }
          ]
        };

        final jsonString = jsonEncode(backupData);

        // Run import
        await backupService.importBackup(jsonString);

        // Verify that original IDs and references were imported successfully
        final grupos = await db.query('grupos');
        expect(grupos, hasLength(1));
        expect(grupos.first['id'], equals(10));
        expect(grupos.first['nome'], equals('Grupo Teste Backup'));

        final pontos = await db.query('pontos_consumo');
        expect(pontos, hasLength(1));
        expect(pontos.first['id'], equals(20));
        expect(pontos.first['grupo_id'], equals(10));

        final historico = await db.query('historico_leituras');
        expect(historico, hasLength(1));
        expect(historico.first['id'], equals(30));
        expect(historico.first['ponto_consumo_id'], equals(20));
        expect(historico.first['valor_leitura'], equals(4321));
      },
      skip: sqliteAvailable ? false : 'libsqlite3.so is not available.',
    );
  });
}

bool _isSqliteAvailable() {
  try {
    DynamicLibrary.open('libsqlite3.so');
    return true;
  } catch (_) {
    return false;
  }
}
