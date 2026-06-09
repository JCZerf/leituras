import 'package:flutter_test/flutter_test.dart';
import 'package:leituras/repositories/ponto_consumo_repository.dart';
import 'package:leituras/viewmodels/preventivo_internos_view_model.dart';

class MockPontoConsumoRepository implements PontoConsumoRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late PreventivoInternosViewModel viewModel;

  setUp(() {
    viewModel = PreventivoInternosViewModel(
      pontoConsumoRepository: MockPontoConsumoRepository(),
    );
  });

  group('PreventivoInternosViewModel Roteiro logic', () {
    test('initial state of isInRoteiroMode is false', () {
      expect(viewModel.isInRoteiroMode, isFalse);
    });

    test('can set and toggle isInRoteiroMode state', () {
      viewModel.isInRoteiroMode = true;
      expect(viewModel.isInRoteiroMode, isTrue);

      viewModel.isInRoteiroMode = false;
      expect(viewModel.isInRoteiroMode, isFalse);
    });

    test('processOcrText returns single match if >= previous reading', () {
      final result = viewModel.processOcrText('Leitura do medidor: 2350', 2340);
      expect(result.suggestions, equals([2350]));
      expect(result.autoFillValue, equals(2350));
    });

    test('processOcrText does not auto-fill single match if < previous reading', () {
      final result = viewModel.processOcrText('Leitura do medidor: 2330', 2340);
      expect(result.suggestions, equals([2330]));
      expect(result.autoFillValue, isNull);
    });

    test('processOcrText returns suggestions but no auto-fill if multiple matches', () {
      final result = viewModel.processOcrText('Medidor 1243 e consumo 5670', 2000);
      expect(result.suggestions, equals([1243, 5670]));
      expect(result.autoFillValue, isNull);
    });
  });
}
