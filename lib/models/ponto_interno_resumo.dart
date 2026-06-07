import 'ponto_consumo_resumo.dart';

class PontoInternoResumo {
  const PontoInternoResumo({
    required this.resumo,
    required this.grupoNome,
  });

  final PontoConsumoResumo resumo;
  final String grupoNome;

  factory PontoInternoResumo.fromMap(Map<String, Object?> map) {
    return PontoInternoResumo(
      resumo: PontoConsumoResumo.fromMap(map),
      grupoNome: map['grupo_nome'] as String? ?? '',
    );
  }
}
