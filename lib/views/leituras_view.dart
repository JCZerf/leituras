import 'package:flutter/material.dart';
import '../models/ponto_consumo.dart';
import '../models/ponto_consumo_resumo.dart';
import '../repositories/grupo_repository.dart';
import '../repositories/historico_leitura_repository.dart';
import '../repositories/ponto_consumo_repository.dart';
import '../theme/app_colors.dart';
import '../viewmodels/app_state.dart';
import '../widgets/app_action_sheet.dart';
import 'leitura_app_bar.dart';
import 'leitura_detail_view.dart';
import 'leitura_form_view.dart';
import 'ponto_edit_form_view.dart';

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
  final _searchFocusNode = FocusNode();
  List<PontoConsumoResumo> _pontos = const [];
  bool _isLoading = false;
  int? _loadedGroupId;
  String _query = '';

  List<PontoConsumoResumo> get _filteredPontos {
    final query = _query.trim().toLowerCase();
    Iterable<PontoConsumoResumo> list = _pontos;

    if (query.isEmpty) {
      return list.toList();
    }
    return list.where((resumo) {
      final p = resumo.ponto;
      return (p.instalacao?.toLowerCase().contains(query) ?? false) ||
          (p.numeroMedidor?.toLowerCase().contains(query) ?? false) ||
          (p.endereco?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  int get _pendingInternalMetersCount {
    final now = DateTime.now();
    return _pontos.where((resumo) {
      final ponto = resumo.ponto;
      if (!ponto.isInterno || ponto.isDesabitado) return false;
      final leitura = resumo.ultimaLeitura;
      if (leitura == null) return true;
      return leitura.dataLeitura.year != now.year ||
          leitura.dataLeitura.month != now.month;
    }).length;
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
    _searchFocusNode.dispose();
    super.dispose();
  }

  Iterable<String> _autocompleteOptions(TextEditingValue value) {
    final query = value.text.trim().toLowerCase();
    if (query.length <= 4) {
      return const <String>[];
    }

    final suggestions = <String>{};
    for (final resumo in _pontos) {
      final ponto = resumo.ponto;
      for (final candidate in [ponto.instalacao, ponto.numeroMedidor]) {
        final text = candidate?.trim();
        if (text == null || text.isEmpty) {
          continue;
        }
        if (text.toLowerCase().startsWith(query)) {
          suggestions.add(text);
        }
      }
      if (suggestions.length >= 6) {
        break;
      }
    }

    return suggestions;
  }

  void _setSearchQuery(String value) {
    setState(() {
      _query = value;
    });
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

  Future<void> _editMeter(PontoConsumo ponto) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PontoEditFormView(
          ponto: ponto,
          pontoConsumoRepository: widget.pontoConsumoRepository,
        ),
      ),
    );
    if (saved == true) {
      await _loadSelectedGroup();
    }
  }

  Future<void> _deleteMeter(PontoConsumo ponto) async {
    final label = ponto.instalacao ?? ponto.numeroMedidor ?? 'medidor';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir medidor'),
        content: Text(
          'Deseja excluir "$label" e todo o seu historico de leituras?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await widget.pontoConsumoRepository.delete(ponto.id!);
    await _loadSelectedGroup();
  }

  void _showMeterActions(PontoConsumo ponto) {
    final label = ponto.instalacao ?? ponto.numeroMedidor ?? 'Medidor';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (ctx) => AppActionSheet(
        title: label,
        icon: Icons.speed_outlined,
        subtitle: 'Acoes do medidor',
        actions: [
          AppActionSheetAction(
            label: 'Editar cadastro',
            subtitle: 'Alterar instalacao, medidor, endereco e tipo.',
            icon: Icons.edit_outlined,
            onPressed: () {
              Navigator.of(ctx).pop();
              _editMeter(ponto);
            },
          ),
          AppActionSheetAction(
            label: 'Excluir medidor',
            subtitle: 'Remove o cadastro e todo o historico de leituras.',
            icon: Icons.delete_outline,
            isDestructive: true,
            onPressed: () {
              Navigator.of(ctx).pop();
              _deleteMeter(ponto);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grupo = widget.appState.selectedGroup;
    final pontos = _filteredPontos;

    final appBarTitle = grupo == null ? 'Leituras' : 'Leituras: ${grupo.nome}';

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
          : FloatingActionButton.extended(
              heroTag: 'fab_leituras',
              onPressed: _createMeter,
              backgroundColor: AppColors.primaryAction,
              foregroundColor: AppColors.background,
              icon: const Icon(Icons.add),
              label: const Text('Leitura'),
            ),
      body: SafeArea(
        child: grupo == null
            ? const _NoGroupSelected()
            : _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  if (_pendingInternalMetersCount > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          border: Border.all(color: AppColors.error, width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: AppColors.error,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '⚠️ $_pendingInternalMetersCount Medidores Internos Pendentes neste Bloco',
                                style: const TextStyle(
                                  color: AppColors.error,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Fixed search bar at the top
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: RawAutocomplete<String>(
                      textEditingController: _searchController,
                      focusNode: _searchFocusNode,
                      optionsBuilder: _autocompleteOptions,
                      onSelected: (value) {
                        _searchController.value = TextEditingValue(
                          text: value,
                          selection: TextSelection.collapsed(
                            offset: value.length,
                          ),
                        );
                        _setSearchQuery(value);
                      },
                      fieldViewBuilder:
                          (context, controller, focusNode, onFieldSubmitted) {
                            return TextField(
                              controller: controller,
                              focusNode: focusNode,
                              onChanged: _setSearchQuery,
                              decoration: InputDecoration(
                                hintText: 'Buscar medidor ou instalação',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: _query.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: 'Limpar busca',
                                        onPressed: () {
                                          controller.clear();
                                          _setSearchQuery('');
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
                            );
                          },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4,
                            color: AppColors.background,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxHeight: 240,
                                maxWidth: 420,
                              ),
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: options.length,
                                itemBuilder: (context, index) {
                                  final option = options.elementAt(index);
                                  return ListTile(
                                    dense: true,
                                    leading: const Icon(Icons.north_west),
                                    title: Text(
                                      option,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.primaryText,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    onTap: () => onSelected(option),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
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
                                onLongPress: () =>
                                    _showMeterActions(resumo.ponto),
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
  const _MeterTile({
    required this.resumo,
    required this.onTap,
    required this.onLongPress,
  });

  final PontoConsumoResumo resumo;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final ponto = resumo.ponto;
    final leitura = resumo.ultimaLeitura;

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
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (ponto.instalacao != null &&
                        ponto.instalacao!.trim().isNotEmpty)
                      Text(
                        'Inst. ${ponto.instalacao}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.primaryText,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    if (ponto.instalacao != null &&
                        ponto.instalacao!.trim().isNotEmpty &&
                        ponto.numeroMedidor != null &&
                        ponto.numeroMedidor!.trim().isNotEmpty)
                      const SizedBox(height: 2),
                    if (ponto.numeroMedidor != null &&
                        ponto.numeroMedidor!.trim().isNotEmpty)
                      Text(
                        'Med. ${ponto.numeroMedidor}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.primaryText,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    if ((ponto.instalacao == null ||
                            ponto.instalacao!.trim().isEmpty) &&
                        (ponto.numeroMedidor == null ||
                            ponto.numeroMedidor!.trim().isEmpty))
                      const Text(
                        '-',
                        style: TextStyle(
                          color: AppColors.primaryText,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    if (ponto.isInterno) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [_buildInternoBadge()],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (leitura != null && ponto.isComposto)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '03: ${leitura.valorLeitura}',
                      style: const TextStyle(
                        color: AppColors.primaryText,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '103: ${leitura.valorProducao ?? "-"}',
                      style: const TextStyle(
                        color: AppColors.primaryText,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  leitura == null
                      ? 'Sem leitura'
                      : 'Leitura: ${leitura.valorLeitura}',
                  style: TextStyle(
                    color: leitura == null
                        ? AppColors.secondaryText
                        : AppColors.primaryText,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Mais opcoes',
                icon: const Icon(
                  Icons.more_vert,
                  color: AppColors.secondaryText,
                  size: 20,
                ),
                onPressed: onLongPress,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInternoBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primaryText,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock, color: AppColors.background, size: 11),
          SizedBox(width: 3),
          Text(
            'INTERNO',
            style: TextStyle(
              color: AppColors.background,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
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
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Nenhum medidor neste grupo.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.secondaryText,
          ),
        ),
      ),
    );
  }
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Nenhum medidor encontrado.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.secondaryText,
          ),
        ),
      ),
    );
  }
}
