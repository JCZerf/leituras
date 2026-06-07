import 'package:flutter/material.dart';
import '../models/grupo.dart';
import '../models/ponto_consumo.dart';
import '../models/ponto_interno_resumo.dart';
import '../repositories/grupo_repository.dart';
import '../repositories/historico_leitura_repository.dart';
import '../repositories/ponto_consumo_repository.dart';
import '../theme/app_colors.dart';
import '../viewmodels/app_state.dart';
import '../viewmodels/preventivo_internos_view_model.dart';
import 'leitura_app_bar.dart';
import 'leitura_form_view.dart';

class PreventivoInternosView extends StatefulWidget {
  const PreventivoInternosView({
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
  State<PreventivoInternosView> createState() => _PreventivoInternosViewState();
}

class _PreventivoInternosViewState extends State<PreventivoInternosView> {
  late final PreventivoInternosViewModel _viewModel;
  bool _showAll = false;
  int? _selectedGroupId;
  int? _lastAppStateGroupId;
  List<Grupo> _grupos = const [];
  late Future<Map<String, List<PontoInternoResumo>>> _groupedFuture;

  @override
  void initState() {
    super.initState();
    _viewModel = PreventivoInternosViewModel(
      pontoConsumoRepository: widget.pontoConsumoRepository,
    );
    _selectedGroupId = widget.appState.selectedGroupId;
    _lastAppStateGroupId = _selectedGroupId;
    widget.appState.addListener(_handleAppStateChanged);
    _loadGroups();
    _loadData();
  }

  @override
  void dispose() {
    widget.appState.removeListener(_handleAppStateChanged);
    super.dispose();
  }

  void _handleAppStateChanged() {
    if (_lastAppStateGroupId != widget.appState.selectedGroupId) {
      _lastAppStateGroupId = widget.appState.selectedGroupId;
      setState(() {
        _selectedGroupId = widget.appState.selectedGroupId;
        _loadData();
      });
    }
  }

  Future<void> _loadGroups() async {
    final grupos = await widget.grupoRepository.findAll();
    if (!mounted) return;
    setState(() {
      _grupos = grupos;
    });
  }

  void _loadData() {
    setState(() {
      _groupedFuture = _viewModel.loadGroupedInternos(
        showAll: _showAll,
        selectedGroupId: _selectedGroupId,
      );
    });
  }

  Future<void> _coletarLeitura(
    BuildContext context,
    PontoConsumo ponto,
    String grupoNome,
  ) async {
    final navigator = Navigator.of(context);
    final grupo = await widget.grupoRepository.findById(ponto.grupoId);
    if (!mounted) return;
    if (grupo == null) return;

    final saved = await navigator.push<bool>(
      MaterialPageRoute(
        builder: (_) => LeituraFormView(
          grupo: grupo,
          ponto: ponto,
          grupoRepository: widget.grupoRepository,
          pontoConsumoRepository: widget.pontoConsumoRepository,
          historicoLeituraRepository: widget.historicoLeituraRepository,
        ),
      ),
    );

    if (saved == true) {
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const LeituraAppBar(title: 'Trabalho Preventivo'),
      body: SafeArea(
        child: Column(
          children: [
            // Group Filter Dropdown
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: DropdownButtonFormField<int?>(
                value: _selectedGroupId,
                decoration: const InputDecoration(
                  labelText: 'Grupo (Regiao)',
                  prefixIcon: Icon(Icons.filter_list),
                ),
                dropdownColor: AppColors.background,
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Todos os grupos'),
                  ),
                  ..._grupos.map((g) => DropdownMenuItem<int?>(
                    value: g.id,
                    child: Text(g.nome),
                  )),
                ],
                onChanged: (val) {
                  setState(() {
                    _selectedGroupId = val;
                    _loadData();
                  });
                },
              ),
            ),
            // Top switch
            SwitchListTile(
              title: const Text(
                'Mostrar todos',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryText,
                ),
              ),
              subtitle: const Text(
                'Incluindo medidores ja coletados',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              value: _showAll,
              onChanged: (val) {
                setState(() {
                  _showAll = val;
                  _loadData();
                });
              },
              activeColor: AppColors.primaryAction,
            ),
            const Divider(
              height: 1,
              thickness: 1.5,
              color: AppColors.primaryText,
            ),
            Expanded(
              child: FutureBuilder<Map<String, List<PontoInternoResumo>>>(
                future: _groupedFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final grouped = snapshot.data ?? const {};
                  if (grouped.isEmpty) {
                    return const _EmptyState();
                  }

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final entry in grouped.entries) ...[
                        _GroupHeader(nome: entry.key),
                        const SizedBox(height: 6),
                        for (final item in entry.value) ...[
                          _PontoInternoCard(
                            item: item,
                            onTap:
                                () => _coletarLeitura(
                                  context,
                                  item.resumo.ponto,
                                  entry.key,
                                ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        const SizedBox(height: 16),
                      ],
                    ],
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

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.nome});

  final String nome;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(
        nome,
        style: const TextStyle(
          color: AppColors.primaryText,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PontoInternoCard extends StatelessWidget {
  const _PontoInternoCard({required this.item, required this.onTap});

  final PontoInternoResumo item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ponto = item.resumo.ponto;
    final isColetado = _checkColetado(item);

    final leitura = item.resumo.ultimaLeitura;
    final readingText = leitura == null
        ? 'Sem leitura'
        : isColetado
            ? 'Leitura: ${leitura.valorLeitura}'
            : 'Última: ${leitura.valorLeitura}';

    return Card(
      color: AppColors.background,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.primaryText, width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (ponto.instalacao != null && ponto.instalacao!.trim().isNotEmpty)
                      Text(
                        'Inst. ${ponto.instalacao}',
                        style: const TextStyle(
                          color: AppColors.primaryText,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    if (ponto.instalacao != null &&
                        ponto.instalacao!.trim().isNotEmpty &&
                        ponto.numeroMedidor != null &&
                        ponto.numeroMedidor!.trim().isNotEmpty)
                      const SizedBox(height: 2),
                    if (ponto.numeroMedidor != null && ponto.numeroMedidor!.trim().isNotEmpty)
                      Text(
                        'Med. ${ponto.numeroMedidor}',
                        style: const TextStyle(
                          color: AppColors.primaryText,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    if ((ponto.instalacao == null || ponto.instalacao!.trim().isEmpty) &&
                        (ponto.numeroMedidor == null || ponto.numeroMedidor!.trim().isEmpty))
                      const Text(
                        '-',
                        style: TextStyle(
                          color: AppColors.primaryText,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    if (ponto.endereco != null && ponto.endereco!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        ponto.endereco!,
                        style: const TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color:
                          isColetado ? AppColors.success : const Color(0xFFFFC107),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isColetado ? 'COLETADO' : 'PENDENTE',
                      style: TextStyle(
                        color:
                            isColetado
                                ? AppColors.background
                                : AppColors.primaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    readingText,
                    style: TextStyle(
                      color: leitura == null
                          ? AppColors.secondaryText
                          : AppColors.primaryText,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _checkColetado(PontoInternoResumo item) {
    final leitura = item.resumo.ultimaLeitura;
    if (leitura == null) return false;
    final now = DateTime.now();
    return leitura.dataLeitura.year == now.year &&
        leitura.dataLeitura.month == now.month;
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.primaryText, width: 1.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'Nenhum medidor interno pendente.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
