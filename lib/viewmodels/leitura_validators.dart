class LeituraValidators {
  const LeituraValidators._();

  static String? grupo(int? grupoId) {
    if (grupoId == null || grupoId <= 0) {
      return 'Selecione um grupo existente.';
    }
    return null;
  }

  static String? pontoConsumo(int? pontoConsumoId) {
    if (pontoConsumoId == null || pontoConsumoId <= 0) {
      return 'Selecione um medidor existente.';
    }
    return null;
  }

  static String? nomeGrupo(String value) {
    if (value.trim().isEmpty) {
      return 'Informe o nome do grupo.';
    }
    return null;
  }

  static String? identificadores({
    required String instalacao,
    required String numeroMedidor,
  }) {
    if (instalacao.trim().isEmpty && numeroMedidor.trim().isEmpty) {
      return 'Informe a instalacao ou o numero do medidor.';
    }
    return null;
  }

  static String? numeroMedidor(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(trimmed)) {
      return 'Use apenas letras e numeros.';
    }
    return null;
  }

  static String? leitura(String value) {
    final trimmed = value.trim();
    if (!RegExp(r'^\d{4,5}$').hasMatch(trimmed)) {
      return 'Informe uma leitura com 4 ou 5 digitos.';
    }
    return null;
  }
}
