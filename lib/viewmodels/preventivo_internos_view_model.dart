import '../models/ponto_interno_resumo.dart';
import '../repositories/ponto_consumo_repository.dart';

class PreventivoInternosViewModel {
  PreventivoInternosViewModel({
    required PontoConsumoRepository pontoConsumoRepository,
  }) : _pontoConsumoRepository = pontoConsumoRepository;

  final PontoConsumoRepository _pontoConsumoRepository;

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
