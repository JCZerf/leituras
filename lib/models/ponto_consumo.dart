class PontoConsumo {
  const PontoConsumo({
    this.id,
    required this.grupoId,
    this.instalacao,
    this.numeroMedidor,
    this.endereco,
  });

  final int? id;
  final int grupoId;
  final String? instalacao;
  final String? numeroMedidor;
  final String? endereco;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'grupo_id': grupoId,
      'instalacao': instalacao,
      'numero_medidor': numeroMedidor,
      'endereco': endereco,
    };
  }

  factory PontoConsumo.fromMap(Map<String, Object?> map) {
    return PontoConsumo(
      id: map['id'] as int?,
      grupoId: map['grupo_id'] as int,
      instalacao: map['instalacao'] as String?,
      numeroMedidor: map['numero_medidor'] as String?,
      endereco: map['endereco'] as String?,
    );
  }
}
