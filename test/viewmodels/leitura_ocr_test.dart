import 'package:flutter_test/flutter_test.dart';
import 'package:leituras/repositories/grupo_repository.dart';
import 'package:leituras/repositories/historico_leitura_repository.dart';
import 'package:leituras/repositories/ponto_consumo_repository.dart';
import 'package:leituras/viewmodels/leitura_form_view_model.dart';

// Simple dummy implementations of the repositories for test instantiation.
class MockGrupoRepository implements GrupoRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockPontoConsumoRepository implements PontoConsumoRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockHistoricoLeituraRepository implements HistoricoLeituraRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late LeituraFormViewModel viewModel;

  setUp(() {
    viewModel = LeituraFormViewModel(
      grupoRepository: MockGrupoRepository(),
      pontoConsumoRepository: MockPontoConsumoRepository(),
      historicoLeituraRepository: MockHistoricoLeituraRepository(),
    );
  });

  group('OCR Fill Assist parsing logic', () {
    test('returns empty suggestions and null autoFill when no 4-5 digit numbers match', () {
      final result = viewModel.processOcrText('Medidor ativo de luz. Consumo s/n abc12', 1000);
      expect(result.suggestions, isEmpty);
      expect(result.autoFillValue, isNull);
    });

    test('auto-fills with singular match if no previous reading exists', () {
      final result = viewModel.processOcrText('Leitura do relogio: 1234 kWh', null);
      expect(result.suggestions, equals([1234]));
      expect(result.autoFillValue, equals(1234));
    });

    test('auto-fills with singular match >= previous reading', () {
      final result = viewModel.processOcrText('Leitura do relogio: 1543 kWh', 1540);
      expect(result.suggestions, equals([1543]));
      expect(result.autoFillValue, equals(1543));
    });

    test('does NOT auto-fill if singular match is less than previous reading (but returns suggestion)', () {
      final result = viewModel.processOcrText('Leitura do relogio: 1530 kWh', 1540);
      expect(result.suggestions, equals([1530]));
      expect(result.autoFillValue, isNull);
    });

    test('does NOT auto-fill if multiple matches exist, returns unique list of suggestions', () {
      final result = viewModel.processOcrText('Medidor: 98432. Leitura: 1520. Serie: 9843', 1000);
      // 98432 has 5 digits, 1520 has 4 digits, 9843 has 4 digits.
      // Order: 98432, 1520, 9843
      expect(result.suggestions, equals([98432, 1520, 9843]));
      expect(result.autoFillValue, isNull);
    });

    test('ignores numbers that are not exactly 4 or 5 digits', () {
      final result = viewModel.processOcrText('Medidor 123 e 123456 com valor 5000', null);
      expect(result.suggestions, equals([5000]));
      expect(result.autoFillValue, equals(5000));
    });

    test('de-duplicates matches correctly', () {
      final result = viewModel.processOcrText('1234 repete 1234 e 5678', null);
      expect(result.suggestions, equals([1234, 5678]));
      expect(result.autoFillValue, isNull);
    });
  });
}
