import 'historico_leitura.dart';
import 'ponto_consumo.dart';

class PontoConsumoResumo {
  const PontoConsumoResumo({required this.ponto, required this.ultimaLeitura});

  final PontoConsumo ponto;
  final HistoricoLeitura? ultimaLeitura;

  factory PontoConsumoResumo.fromMap(Map<String, Object?> map) {
    return PontoConsumoResumo(
      ponto: PontoConsumo.fromMap(map),
      ultimaLeitura: map['ultima_leitura_id'] == null
          ? null
          : HistoricoLeitura(
              id: map['ultima_leitura_id'] as int?,
              pontoConsumoId: map['id'] as int,
              valorLeitura: map['ultima_valor_leitura'] as int,
              valorProducao: map['ultima_valor_producao'] as int?,
              dataLeitura: DateTime.parse(
                (map['ultima_data_leitura'] as String).replaceFirst(' ', 'T'),
              ),
              fotoPath: map['ultima_foto_path'] as String?,
              fotoDescricao: map['ultima_foto_descricao'] as String?,
            ),
    );
  }
}
