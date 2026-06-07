class Grupo {
  const Grupo({
    this.id,
    required this.nome,
    this.descricao,
    required this.dataCriacao,
  });

  final int? id;
  final String nome;
  final String? descricao;
  final DateTime dataCriacao;

  Grupo copyWith({
    int? id,
    String? nome,
    String? descricao,
    DateTime? dataCriacao,
  }) {
    return Grupo(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      descricao: descricao ?? this.descricao,
      dataCriacao: dataCriacao ?? this.dataCriacao,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'nome': nome,
      'descricao': descricao,
      'data_criacao': dataCriacao.toIso8601String(),
    };
  }

  factory Grupo.fromMap(Map<String, Object?> map) {
    return Grupo(
      id: map['id'] as int?,
      nome: map['nome'] as String,
      descricao: map['descricao'] as String?,
      dataCriacao: DateTime.parse(map['data_criacao'] as String),
    );
  }
}
