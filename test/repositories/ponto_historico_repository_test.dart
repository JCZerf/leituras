import 'dart:ffi';

import 'package:flutter_test/flutter_test.dart';
import 'package:leituras/models/grupo.dart';
import 'package:leituras/models/historico_leitura.dart';
import 'package:leituras/models/ponto_consumo.dart';
import 'package:leituras/repositories/app_database.dart';
import 'package:leituras/repositories/grupo_repository.dart';
import 'package:leituras/repositories/historico_leitura_repository.dart';
import 'package:leituras/repositories/ponto_consumo_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppDatabase database;
  late GrupoRepository grupoRepository;
  late PontoConsumoRepository pontoRepository;
  late HistoricoLeituraRepository historicoRepository;
  final sqliteAvailable = _isSqliteAvailable();

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() {
    database = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    grupoRepository = GrupoRepository(database);
    pontoRepository = PontoConsumoRepository(database);
    historicoRepository = HistoricoLeituraRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'creates point and preserves multiple readings in history',
    () async {
      final grupoId = await grupoRepository.insert(
        Grupo(nome: 'Bloco A', dataCriacao: DateTime(2026)),
      );
      final pontoId = await pontoRepository.insert(
        PontoConsumo(grupoId: grupoId, instalacao: 'A1'),
      );

      await historicoRepository.insert(
        HistoricoLeitura(
          pontoConsumoId: pontoId,
          valorLeitura: 1234,
          dataLeitura: DateTime(2026, 1, 1, 10),
        ),
      );
      await historicoRepository.insert(
        HistoricoLeitura(
          pontoConsumoId: pontoId,
          valorLeitura: 2345,
          dataLeitura: DateTime(2026, 1, 2, 10),
        ),
      );

      final historico = await historicoRepository.findByPontoConsumoId(pontoId);

      expect(historico, hasLength(2));
      expect(historico.first.valorLeitura, 2345);
      expect(historico.last.valorLeitura, 1234);
    },
    skip: sqliteAvailable ? false : 'libsqlite3.so is not available.',
  );

  test(
    'lists points by group with latest reading',
    () async {
      final grupoA = await grupoRepository.insert(
        Grupo(nome: 'Bloco A', dataCriacao: DateTime(2026)),
      );
      final grupoB = await grupoRepository.insert(
        Grupo(nome: 'Bloco B', dataCriacao: DateTime(2026)),
      );
      final pontoA = await pontoRepository.insert(
        PontoConsumo(grupoId: grupoA, instalacao: 'A1'),
      );
      final pontoB = await pontoRepository.insert(
        PontoConsumo(grupoId: grupoB, instalacao: 'B1'),
      );

      await historicoRepository.insert(
        HistoricoLeitura(
          pontoConsumoId: pontoA,
          valorLeitura: 1234,
          dataLeitura: DateTime(2026, 1, 1),
        ),
      );
      await historicoRepository.insert(
        HistoricoLeitura(
          pontoConsumoId: pontoA,
          valorLeitura: 2345,
          dataLeitura: DateTime(2026, 1, 2),
        ),
      );
      await historicoRepository.insert(
        HistoricoLeitura(
          pontoConsumoId: pontoB,
          valorLeitura: 5678,
          dataLeitura: DateTime(2026, 1, 3),
        ),
      );

      final pontos = await pontoRepository.findResumoByGrupoId(grupoA);

      expect(pontos, hasLength(1));
      expect(pontos.single.ponto.instalacao, 'A1');
      expect(pontos.single.ultimaLeitura!.valorLeitura, 2345);
    },
    skip: sqliteAvailable ? false : 'libsqlite3.so is not available.',
  );

  test(
    'rejects history linked to a missing point',
    () async {
      expect(
        () => historicoRepository.insert(
          HistoricoLeitura(
            pontoConsumoId: 999,
            valorLeitura: 1234,
            dataLeitura: DateTime(2026),
          ),
        ),
        throwsA(isA<DatabaseException>()),
      );
    },
    skip: sqliteAvailable ? false : 'libsqlite3.so is not available.',
  );

  test(
    'updates a reading without creating a new history entry',
    () async {
      final grupoId = await grupoRepository.insert(
        Grupo(nome: 'Bloco A', dataCriacao: DateTime(2026)),
      );
      final pontoId = await pontoRepository.insert(
        PontoConsumo(grupoId: grupoId, instalacao: 'A1'),
      );
      final leituraId = await historicoRepository.insert(
        HistoricoLeitura(
          pontoConsumoId: pontoId,
          valorLeitura: 1234,
          dataLeitura: DateTime(2026, 1, 1, 10),
        ),
      );

      await historicoRepository.update(
        HistoricoLeitura(
          id: leituraId,
          pontoConsumoId: pontoId,
          valorLeitura: 1284,
          dataLeitura: DateTime(2026, 1, 1, 10),
        ),
      );

      final historico = await historicoRepository.findByPontoConsumoId(pontoId);

      expect(historico, hasLength(1));
      expect(historico.single.id, leituraId);
      expect(historico.single.valorLeitura, 1284);
    },
    skip: sqliteAvailable ? false : 'libsqlite3.so is not available.',
  );

  test(
    'deletes latest reading and summary falls back to previous reading',
    () async {
      final grupoId = await grupoRepository.insert(
        Grupo(nome: 'Bloco A', dataCriacao: DateTime(2026)),
      );
      final pontoId = await pontoRepository.insert(
        PontoConsumo(grupoId: grupoId, instalacao: 'A1'),
      );
      await historicoRepository.insert(
        HistoricoLeitura(
          pontoConsumoId: pontoId,
          valorLeitura: 1234,
          dataLeitura: DateTime(2026, 1, 1, 10),
        ),
      );
      final latestId = await historicoRepository.insert(
        HistoricoLeitura(
          pontoConsumoId: pontoId,
          valorLeitura: 2345,
          dataLeitura: DateTime(2026, 1, 2, 10),
        ),
      );

      await historicoRepository.delete(latestId);

      final pontos = await pontoRepository.findResumoByGrupoId(grupoId);
      final historico = await historicoRepository.findByPontoConsumoId(pontoId);

      expect(historico, hasLength(1));
      expect(pontos.single.ultimaLeitura!.valorLeitura, 1234);
    },
    skip: sqliteAvailable ? false : 'libsqlite3.so is not available.',
  );
}

bool _isSqliteAvailable() {
  try {
    DynamicLibrary.open('libsqlite3.so');
    return true;
  } catch (_) {
    return false;
  }
}
