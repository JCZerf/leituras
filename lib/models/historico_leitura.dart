class HistoricoLeitura {
  const HistoricoLeitura({
    this.id,
    required this.pontoConsumoId,
    required this.valorLeitura,
    this.valorProducao,
    required this.dataLeitura,
    this.fotoPath,
    this.fotoDescricao,
  });

  final int? id;
  final int pontoConsumoId;
  final int valorLeitura;
  final int? valorProducao;
  final DateTime dataLeitura;
  final String? fotoPath;
  final String? fotoDescricao;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'ponto_consumo_id': pontoConsumoId,
      'valor_leitura': valorLeitura,
      'valor_producao': valorProducao,
      'data_leitura': _formatSqliteDateTime(dataLeitura),
      'foto_path': fotoPath,
      'foto_descricao': fotoDescricao,
    };
  }

  factory HistoricoLeitura.fromMap(Map<String, Object?> map) {
    return HistoricoLeitura(
      id: map['id'] as int?,
      pontoConsumoId: map['ponto_consumo_id'] as int,
      valorLeitura: map['valor_leitura'] as int,
      valorProducao: map['valor_producao'] as int?,
      dataLeitura: _parseSqliteDateTime(map['data_leitura'] as String),
      fotoPath: map['foto_path'] as String?,
      fotoDescricao: map['foto_descricao'] as String?,
    );
  }

  static String _formatSqliteDateTime(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }

  static DateTime _parseSqliteDateTime(String value) {
    return DateTime.parse(value.replaceFirst(' ', 'T'));
  }
}
