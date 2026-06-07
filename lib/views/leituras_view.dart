import 'package:flutter/material.dart';
import '../models/ponto_consumo.dart';
import '../models/ponto_consumo_resumo.dart';
import '../repositories/grupo_repository.dart';
import '../repositories/historico_leitura_repository.dart';
import '../repositories/ponto_consumo_repository.dart';
import '../theme/app_colors.dart';
import '../viewmodels/app_state.dart';
import 'leitura_app_bar.dart';
import 'leitura_detail_view.dart';
import 'leitura_form_view.dart';

class LeiturasView extends StatefulWidget {
  const LeiturasView({
    super.key,
    required this.appState,
    required this.grupoRepository,
    required this.pontoConsumoRepository,
    required this.historicoLeituraRepository,
  });

  final AppState appState;
  final GrupoRepository grupoRepository;
  final PontoConsumoRepository pontoConsumoRepository;
  final HistoricoLeituraRepository historicoLeituraRepository;

  @override
  State<LeiturasView> createState() => _LeiturasViewState();
}

class _LeiturasViewState extends State<LeiturasView> {
  final _searchController = TextEditingController();
  List<PontoConsumoResumo> _pontos = const [];
  bool _isLoading = false;
  int? _loadedGroupId;
  String _query = '';

  List<PontoConsumoResumo> get _filteredPontos {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return _pontos;
    }
    return _pontos.where((resumo) {
      final p = resumo.ponto;
      return (p.instalacao?.toLowerCase().contains(query) ?? false) ||
          (p.numeroMedidor?.toLowerCase().contains(query) ?? false) ||
          (p.endereco?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    widget.appState.addListener(_handleAppStateChanged);
    _loadSelectedGroup();
  }

  @override
  void dispose() {
    widget.appState.removeListener(_handleAppStateChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _handleAppStateChanged() {
    if (_loadedGroupId != widget.appState.selectedGroupId) {
      _loadSelectedGroup();
    }
  }

  Future<void> _loadSelectedGroup() async {
    final groupId = widget.appState.selectedGroupId;
    _loadedGroupId = groupId;

    if (groupId == null) {
      setState(() {
        _pontos = const [];
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final pontos = await widget.pontoConsumoRepository.findResumoByGrupoId(
      groupId,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _pontos = pontos;
      _isLoading = false;
    });
  }

  Future<void> _createMeter() async {
    final grupo = widget.appState.selectedGroup;
    if (grupo == null) {
      return;
    }

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LeituraFormView(
          grupo: grupo,
          grupoRepository: widget.grupoRepository,
          pontoConsumoRepository: widget.pontoConsumoRepository,
          historicoLeituraRepository: widget.historicoLeituraRepository,
        ),
      ),
    );
    if (saved == true) {
      await _loadSelectedGroup();
    }
  }

  Future<void> _openDetail(PontoConsumo ponto) async {
    final grupo = widget.appState.selectedGroup;
    if (grupo == null) {
      return;
    }

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LeituraDetailView(
          grupo: grupo,
          ponto: ponto,
          grupoRepository: widget.grupoRepository,
          pontoConsumoRepository: widget.pontoConsumoRepository,
          historicoLeituraRepository: widget.historicoLeituraRepository,
        ),
      ),
    );
    if (changed == true) {
      await _loadSelectedGroup();
    }
  }

  @override
  Widget build(BuildContext context) {
    final grupo = widget.appState.selectedGroup;
    final pontos = _filteredPontos;

    final appBarTitle = grupo == null
        ? 'Leituras'
        : 'Leituras: ${grupo.nome}';

    return Scaffold(
      appBar: LeituraAppBar(
        title: appBarTitle,
        actions: grupo == null
            ? null
            : [
                IconButton(
                  tooltip: 'Novo medidor',
                  onPressed: _createMeter,
                  icon: const Icon(Icons.add),
                ),
              ],
      ),
      floatingActionButton: grupo == null
          ? null
          : FloatingActionButton(
              onPressed: _createMeter,
              backgroundColor: AppColors.primaryAction,
              foregroundColor: AppColors.background,
              child: const Icon(Icons.add),
            ),
      body: SafeArea(
        child: grupo == null
            ? const _NoGroupSelected()
            : _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Fixed search bar at the top
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() {
                          _query = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Buscar medidor',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Limpar busca',
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _query = '';
                                  });
                                },
                                icon: const Icon(Icons.close),
                              ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppColors.primaryText,
                            width: 1.5,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppColors.primaryText,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppColors.primaryAction,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Scrollable meter list
                  Expanded(
                    child: pontos.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(16),
                            child: _query.trim().isNotEmpty
                                ? const _EmptySearch()
                                : const _EmptyMeters(),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                            itemCount: pontos.length,
                            itemBuilder: (context, index) {
                              final resumo = pontos[index];
                              return _MeterTile(
                                resumo: resumo,
                                onTap: () => _openDetail(resumo.ponto),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _MeterTile extends StatelessWidget {
  const _MeterTile({required this.resumo, required this.onTap});

  final PontoConsumoResumo resumo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ponto = resumo.ponto;
    final leitura = resumo.ultimaLeitura;

    // Show instalação as primary label when available, otherwise medidor.
    final primaryLabel = ponto.instalacao != null && ponto.instalacao!.isNotEmpty
        ? ponto.instalacao!
        : ponto.numeroMedidor ?? '-';

    final readingText = leitura == null
        ? 'Sem leitura'
        : 'Leitura: ${leitura.valorLeitura}';

    return Card(
      color: AppColors.background,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.primaryText, width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  primaryLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                readingText,
                style: TextStyle(
                  color: leitura == null
                      ? AppColors.secondaryText
                      : AppColors.primaryText,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.chevron_right,
                color: AppColors.secondaryText,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoGroupSelected extends StatelessWidget {
  const _NoGroupSelected();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Selecione um grupo na aba anterior',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _EmptyMeters extends StatelessWidget {
  const _EmptyMeters();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primaryText, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'Nenhum medidor neste grupo.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primaryText, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'Nenhum medidor encontrado.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }
}
