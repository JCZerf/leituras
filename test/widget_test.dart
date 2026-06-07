import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leituras/models/grupo.dart';
import 'package:leituras/models/historico_leitura.dart';
import 'package:leituras/models/ponto_consumo.dart';
import 'package:leituras/models/ponto_consumo_resumo.dart';
import 'package:leituras/repositories/app_database.dart';
import 'package:leituras/repositories/grupo_repository.dart';
import 'package:leituras/repositories/historico_leitura_repository.dart';
import 'package:leituras/repositories/ponto_consumo_repository.dart';
import 'package:leituras/views/main_navigation.dart';

void main() {
  testWidgets('shows no group message on readings tab without selection', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MainNavigation(
          grupoRepository: _FakeGrupoRepository(groups: const []),
          pontoConsumoRepository: _FakePontoConsumoRepository(pontos: const []),
          historicoLeituraRepository: _FakeHistoricoRepository(
            historico: const [],
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Leituras'));
    await tester.pump();

    expect(find.text('Selecione um grupo na aba anterior'), findsOneWidget);
  });

  testWidgets('selects group and navigates to readings tab', (
    WidgetTester tester,
  ) async {
    final group = Grupo(id: 1, nome: 'Bloco A', dataCriacao: _fixedDate);
    final ponto = PontoConsumo(
      id: 1,
      grupoId: 1,
      instalacao: 'A1',
      endereco: 'Rua Central',
    );
    final historico = HistoricoLeitura(
      id: 1,
      pontoConsumoId: 1,
      valorLeitura: 12345,
      dataLeitura: _fixedDate,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MainNavigation(
          grupoRepository: _FakeGrupoRepository(groups: [group]),
          pontoConsumoRepository: _FakePontoConsumoRepository(
            pontos: [
              PontoConsumoResumo(ponto: ponto, ultimaLeitura: historico),
            ],
          ),
          historicoLeituraRepository: _FakeHistoricoRepository(
            historico: [historico],
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Bloco A'));
    await tester.pump();

    expect(find.text('Leitura: 12345'), findsOneWidget);
    expect(find.text('A1'), findsOneWidget);
  });
}

final _fixedDate = DateTime(2026);

class _FakeGrupoRepository extends GrupoRepository {
  _FakeGrupoRepository({required this.groups}) : super(AppDatabase());

  final List<Grupo> groups;

  @override
  Future<List<Grupo>> findAll() async => groups;

  @override
  Future<Grupo?> findById(int id) async {
    for (final group in groups) {
      if (group.id == id) {
        return group;
      }
    }
    return null;
  }
}

class _FakePontoConsumoRepository extends PontoConsumoRepository {
  _FakePontoConsumoRepository({required this.pontos}) : super(AppDatabase());

  final List<PontoConsumoResumo> pontos;

  @override
  Future<List<PontoConsumoResumo>> findResumoByGrupoId(int grupoId) async {
    return pontos.where((resumo) => resumo.ponto.grupoId == grupoId).toList();
  }

  @override
  Future<PontoConsumo?> findById(int id) async {
    for (final resumo in pontos) {
      if (resumo.ponto.id == id) {
        return resumo.ponto;
      }
    }
    return null;
  }
}

class _FakeHistoricoRepository extends HistoricoLeituraRepository {
  _FakeHistoricoRepository({required this.historico}) : super(AppDatabase());

  final List<HistoricoLeitura> historico;

  @override
  Future<List<HistoricoLeitura>> findByPontoConsumoId(
    int pontoConsumoId,
  ) async {
    return historico
        .where((item) => item.pontoConsumoId == pontoConsumoId)
        .toList();
  }
}
