class PontoConsumo {
  const PontoConsumo({
    this.id,
    required this.grupoId,
    this.instalacao,
    this.numeroMedidor,
    this.endereco,
    this.isInterno = false,
  });

  final int? id;
  final int grupoId;
  final String? instalacao;
  final String? numeroMedidor;
  final String? endereco;
  final bool isInterno;

  PontoConsumo copyWith({
    int? id,
    int? grupoId,
    String? instalacao,
    String? numeroMedidor,
    String? endereco,
    bool? isInterno,
  }) {
    return PontoConsumo(
      id: id ?? this.id,
      grupoId: grupoId ?? this.grupoId,
      instalacao: instalacao ?? this.instalacao,
      numeroMedidor: numeroMedidor ?? this.numeroMedidor,
      endereco: endereco ?? this.endereco,
      isInterno: isInterno ?? this.isInterno,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'grupo_id': grupoId,
      'instalacao': instalacao,
      'numero_medidor': numeroMedidor,
      'endereco': endereco,
      'is_interno': isInterno ? 1 : 0,
    };
  }

  factory PontoConsumo.fromMap(Map<String, Object?> map) {
    return PontoConsumo(
      id: map['id'] as int?,
      grupoId: map['grupo_id'] as int,
      instalacao: map['instalacao'] as String?,
      numeroMedidor: map['numero_medidor'] as String?,
      endereco: map['endereco'] as String?,
      isInterno: (map['is_interno'] as int? ?? 0) == 1,
    );
  }
}
