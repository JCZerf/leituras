import '../models/ponto_interno_resumo.dart';
import '../repositories/ponto_consumo_repository.dart';
import 'leitura_form_view_model.dart';

class PreventivoInternosViewModel {
  PreventivoInternosViewModel({
    required PontoConsumoRepository pontoConsumoRepository,
  }) : _pontoConsumoRepository = pontoConsumoRepository;

  final PontoConsumoRepository _pontoConsumoRepository;
  bool isInRoteiroMode = false;

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

  /// Loads all internal points and groups them by group name.
  /// If [showAll] is false, filters out points that have a reading in the current month/year.
  /// If [selectedGroupId] is non-null, filters points by group.
  Future<Map<String, List<PontoInternoResumo>>> loadGroupedInternos({
    required bool showAll,
    int? selectedGroupId,
  }) async {
    final list = await _pontoConsumoRepository.findAllInternosResumo();
    final now = DateTime.now();

    final filtered = list.where((item) {
      if (selectedGroupId != null &&
          item.resumo.ponto.grupoId != selectedGroupId) {
        return false;
      }
      if (showAll) return true;
      final leitura = item.resumo.ultimaLeitura;
      if (leitura == null) return true;
      return leitura.dataLeitura.year != now.year ||
          leitura.dataLeitura.month != now.month;
    });

    final grouped = <String, List<PontoInternoResumo>>{};
    for (final item in filtered) {
      grouped.putIfAbsent(item.grupoNome, () => []).add(item);
    }
    return grouped;
  }
}
