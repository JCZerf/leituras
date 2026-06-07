import 'package:flutter/foundation.dart';

import '../models/grupo.dart';
import '../models/ponto_consumo_resumo.dart';
import '../repositories/grupo_repository.dart';
import '../repositories/ponto_consumo_repository.dart';
import 'leitura_validators.dart';

class HomeViewModel extends ChangeNotifier {
  HomeViewModel({
    required GrupoRepository grupoRepository,
    required PontoConsumoRepository pontoConsumoRepository,
  }) : _grupoRepository = grupoRepository,
       _pontoConsumoRepository = pontoConsumoRepository;

  final GrupoRepository _grupoRepository;
  final PontoConsumoRepository _pontoConsumoRepository;

  List<Grupo> grupos = const [];
  List<PontoConsumoResumo> pontos = const [];
  String searchQuery = '';
  Grupo? grupoSelecionado;
  bool isLoading = false;
  String? errorMessage;

  List<PontoConsumoResumo> get pontosFiltrados {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return pontos;
    }

    return pontos.where((resumo) {
      final ponto = resumo.ponto;
      final instalacao = ponto.instalacao?.toLowerCase() ?? '';
      final medidor = ponto.numeroMedidor?.toLowerCase() ?? '';
      return instalacao.contains(query) || medidor.contains(query);
    }).toList();
  }

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      grupos = await _grupoRepository.findAll();
      if (grupos.isEmpty) {
        grupoSelecionado = null;
        pontos = const [];
      } else {
        final selectedId = grupoSelecionado?.id;
        grupoSelecionado = grupos.firstWhere(
          (grupo) => grupo.id == selectedId,
          orElse: () => grupos.first,
        );
        await _loadPontos();
      }
    } catch (_) {
      errorMessage = 'Nao foi possivel carregar os medidores.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectGrupo(Grupo grupo) async {
    grupoSelecionado = grupo;
    searchQuery = '';
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _loadPontos();
    } catch (_) {
      errorMessage = 'Nao foi possivel carregar este grupo.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createGrupo({required String nome, String? descricao}) async {
    final validation = LeituraValidators.nomeGrupo(nome);
    if (validation != null) {
      throw ArgumentError(validation);
    }

    final id = await _grupoRepository.insert(
      Grupo(
        nome: nome.trim(),
        descricao: _optional(descricao),
        dataCriacao: DateTime.now(),
      ),
    );
    grupoSelecionado = Grupo(
      id: id,
      nome: nome.trim(),
      descricao: _optional(descricao),
      dataCriacao: DateTime.now(),
    );
    await load();
  }

  Future<void> _loadPontos() async {
    final grupoId = grupoSelecionado?.id;
    if (grupoId == null) {
      pontos = const [];
      return;
    }
    pontos = await _pontoConsumoRepository.findResumoByGrupoId(grupoId);
  }

  void updateSearch(String value) {
    searchQuery = value;
    notifyListeners();
  }

  static String? _optional(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}
