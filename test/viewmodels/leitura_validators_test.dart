import 'package:flutter_test/flutter_test.dart';
import 'package:leituras/viewmodels/leitura_validators.dart';

void main() {
  test('rejects empty group name', () {
    expect(LeituraValidators.nomeGrupo('  '), isNotNull);
  });

  test('rejects missing group', () {
    expect(LeituraValidators.grupo(null), isNotNull);
    expect(LeituraValidators.grupo(0), isNotNull);
  });

  test('rejects missing strong identifier', () {
    expect(
      LeituraValidators.identificadores(instalacao: '', numeroMedidor: ''),
      isNotNull,
    );
  });

  test('rejects readings outside 4 or 5 digits', () {
    expect(LeituraValidators.leitura('123'), isNotNull);
    expect(LeituraValidators.leitura('123456'), isNotNull);
    expect(LeituraValidators.leitura('12a4'), isNotNull);
  });

  test('accepts valid readings and identifiers', () {
    expect(LeituraValidators.leitura('1234'), isNull);
    expect(LeituraValidators.leitura('12345'), isNull);
    expect(
      LeituraValidators.identificadores(instalacao: 'ABC', numeroMedidor: ''),
      isNull,
    );
    expect(
      LeituraValidators.identificadores(instalacao: '', numeroMedidor: 'M123'),
      isNull,
    );
  });
}
