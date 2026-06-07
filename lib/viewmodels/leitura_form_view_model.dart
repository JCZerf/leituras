import '../models/historico_leitura.dart';
import '../models/ponto_consumo.dart';
import '../repositories/grupo_repository.dart';
import '../repositories/historico_leitura_repository.dart';
import '../repositories/ponto_consumo_repository.dart';
import 'leitura_validators.dart';

class LeituraFormViewModel {
  const LeituraFormViewModel({
    required GrupoRepository grupoRepository,
    required PontoConsumoRepository pontoConsumoRepository,
    required HistoricoLeituraRepository historicoLeituraRepository,
  }) : _grupoRepository = grupoRepository,
       _pontoConsumoRepository = pontoConsumoRepository,
       _historicoLeituraRepository = historicoLeituraRepository;

  final GrupoRepository _grupoRepository;
  final PontoConsumoRepository _pontoConsumoRepository;
  final HistoricoLeituraRepository _historicoLeituraRepository;

  Future<void> createPontoComLeitura({
    required int? grupoId,
    required String instalacao,
    required String numeroMedidor,
    required String leitura,
    String? endereco,
    String? fotoPath,
    String? fotoDescricao,
    bool isInterno = false,
  }) async {
    final errors = [
      LeituraValidators.grupo(grupoId),
      LeituraValidators.identificadores(
        instalacao: instalacao,
        numeroMedidor: numeroMedidor,
      ),
      LeituraValidators.numeroMedidor(numeroMedidor),
      LeituraValidators.leitura(leitura),
    ].whereType<String>().toList();

    if (errors.isNotEmpty) {
      throw ArgumentError(errors.first);
    }

    final grupo = await _grupoRepository.findById(grupoId!);
    if (grupo == null) {
      throw ArgumentError('Selecione um grupo existente.');
    }

    final pontoId = await _pontoConsumoRepository.insert(
      PontoConsumo(
        grupoId: grupoId,
        instalacao: _optional(instalacao),
        numeroMedidor: _optional(numeroMedidor),
        endereco: _optional(endereco),
        isInterno: isInterno,
      ),
    );
    await addHistorico(
      pontoConsumoId: pontoId,
      leitura: leitura,
      fotoPath: fotoPath,
      fotoDescricao: fotoDescricao,
    );
  }

  Future<void> addHistorico({
    required int? pontoConsumoId,
    required String leitura,
    String? fotoPath,
    String? fotoDescricao,
  }) async {
    final errors = [
      LeituraValidators.pontoConsumo(pontoConsumoId),
      LeituraValidators.leitura(leitura),
    ].whereType<String>().toList();

    if (errors.isNotEmpty) {
      throw ArgumentError(errors.first);
    }

    final ponto = await _pontoConsumoRepository.findById(pontoConsumoId!);
    if (ponto == null) {
      throw ArgumentError('Selecione um medidor existente.');
    }

    await _historicoLeituraRepository.insert(
      HistoricoLeitura(
        pontoConsumoId: pontoConsumoId,
        valorLeitura: int.parse(leitura.trim()),
        dataLeitura: DateTime.now(),
        fotoPath: fotoPath,
        fotoDescricao: _optional(fotoDescricao),
      ),
    );
  }

  OcrProcessingResult processOcrText(String text, int? ultimoValorLeitura) {
    final regex = RegExp(r'\b\d{4,5}\b');
    final matches = regex.allMatches(text);

    final candidates = <int>[];
    for (final match in matches) {
      final value = int.tryParse(match.group(0) ?? '');
      if (value != null && !candidates.contains(value)) {
        candidates.add(value);
      }
    }

    if (candidates.length == 1) {
      final value = candidates.first;
      if (ultimoValorLeitura == null || value >= ultimoValorLeitura) {
        return OcrProcessingResult(
          suggestions: candidates,
          autoFillValue: value,
        );
      }
    }

    return OcrProcessingResult(
      suggestions: candidates,
      autoFillValue: null,
    );
  }

  static String? _optional(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}

class OcrProcessingResult {
  final List<int> suggestions;
  final int? autoFillValue;

  const OcrProcessingResult({
    required this.suggestions,
    this.autoFillValue,
  });
}
