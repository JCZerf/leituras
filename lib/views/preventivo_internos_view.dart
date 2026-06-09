import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/grupo.dart';
import '../models/ponto_consumo.dart';
import '../models/ponto_interno_resumo.dart';
import '../models/historico_leitura.dart';
import '../repositories/grupo_repository.dart';
import '../repositories/historico_leitura_repository.dart';
import '../repositories/ponto_consumo_repository.dart';
import '../services/camera_service.dart';
import '../services/ocr_service.dart';
import '../theme/app_colors.dart';
import '../viewmodels/app_state.dart';
import '../viewmodels/preventivo_internos_view_model.dart';
import '../viewmodels/leitura_validators.dart';
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
  late final CameraService _cameraService;
  late final OcrService _ocrService;

  bool _showAll = false;
  int? _selectedGroupId;
  int? _lastAppStateGroupId;
  List<Grupo> _grupos = const [];

  Map<String, List<PontoInternoResumo>> _groupedItems = const {};
  List<PontoInternoResumo> _flatItems = const [];
  List<_RoteiroItemState> _roteiroStates = const [];
  bool _isLoading = false;
  bool _showConcluidosInRoteiro = false;

  @override
  void initState() {
    super.initState();
    _viewModel = PreventivoInternosViewModel(
      pontoConsumoRepository: widget.pontoConsumoRepository,
    );
    _cameraService = CameraService();
    _ocrService = OcrService();
    _selectedGroupId = widget.appState.selectedGroupId;
    _lastAppStateGroupId = _selectedGroupId;
    widget.appState.addListener(_handleAppStateChanged);
    _loadGroups();
    _loadData();
  }

  @override
  void dispose() {
    widget.appState.removeListener(_handleAppStateChanged);
    for (final state in _roteiroStates) {
      state.dispose();
    }
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

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    try {
      final grouped = await _viewModel.loadGroupedInternos(
        showAll: _showAll,
        selectedGroupId: _selectedGroupId,
      );
      if (!mounted) return;
      setState(() {
        _groupedItems = grouped;
        _flatItems = grouped.values.expand((x) => x).toList();
        if (_viewModel.isInRoteiroMode) {
          _syncRoteiroItems();
        }
      });
    } catch (e) {
      debugPrint('Erro ao carregar dados: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _syncRoteiroItems() {
    final newStates = <_RoteiroItemState>[];
    for (final item in _flatItems) {
      final existing = _roteiroStates.firstWhere(
        (s) => s.item.resumo.ponto.id == item.resumo.ponto.id,
        orElse: () => _RoteiroItemState(
          item: item,
          controller: TextEditingController(),
          focusNode: FocusNode(),
        ),
      );
      newStates.add(existing);
    }
    _roteiroStates = newStates;
  }

  void _startRoteiro() {
    if (_flatItems.isEmpty) return;

    for (final s in _roteiroStates) {
      s.dispose();
    }

    _roteiroStates = _flatItems.map((item) {
      return _RoteiroItemState(
        item: item,
        controller: TextEditingController(),
        focusNode: FocusNode(),
      );
    }).toList();

    setState(() {
      _viewModel.isInRoteiroMode = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusFirstPending();
    });
  }

  void _stopRoteiro() {
    for (final s in _roteiroStates) {
      s.dispose();
    }
    _roteiroStates = const [];
    setState(() {
      _viewModel.isInRoteiroMode = false;
    });
    _loadData();
  }

  void _focusFirstPending() {
    for (final state in _roteiroStates) {
      final isColetado = _isItemColetado(state.item) || state.justSaved;
      if (!isColetado) {
        state.focusNode.requestFocus();
        break;
      }
    }
  }

  bool _isItemColetado(PontoInternoResumo item) {
    if (item.resumo.ponto.isDesabitado) return true;
    final leitura = item.resumo.ultimaLeitura;
    if (leitura == null) return false;
    final now = DateTime.now();
    return leitura.dataLeitura.year == now.year &&
        leitura.dataLeitura.month == now.month;
  }

  Future<void> _captureCardPhoto(_RoteiroItemState state) async {
    try {
      final path = await _cameraService.capturePhoto();
      if (path != null) {
        setState(() {
          state.fotoPath = path;
          state.isOcrProcessing = true;
          state.errorMessage = null;
        });

        try {
          final rawText = await _ocrService.recognizeText(path);
          state.ocrRawText = rawText;
        } catch (e) {
          debugPrint('Erro no processamento OCR: $e');
        } finally {
          setState(() {
            state.isOcrProcessing = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        state.errorMessage = 'Erro ao capturar foto: $e';
      });
    }
  }

  Future<void> _saveRoteiroLeitura(_RoteiroItemState state) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final valText = state.controller.text.trim();
    final validatorError = LeituraValidators.leitura(valText);
    if (validatorError != null) {
      setState(() {
        state.errorMessage = validatorError;
      });
      return;
    }

    final val = int.parse(valText);
    final lastReading = state.item.resumo.ultimaLeitura?.valorLeitura;
    if (lastReading != null && val < lastReading) {
      setState(() {
        state.errorMessage = 'Valor menor que anterior ($lastReading).';
      });
      return;
    }

    setState(() {
      state.isSaving = true;
      state.errorMessage = null;
    });

    try {
      await widget.historicoLeituraRepository.insert(
        HistoricoLeitura(
          pontoConsumoId: state.item.resumo.ponto.id!,
          valorLeitura: val,
          dataLeitura: DateTime.now(),
          fotoPath: state.fotoPath,
          fotoDescricao: state.ocrRawText,
        ),
      );

      setState(() {
        state.justSaved = true;
        state.focusNode.unfocus();
      });

      if (mounted) {
        scaffoldMessenger.clearSnackBars();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: AppColors.background,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Leitura salva: $valText (Inst. ${state.item.resumo.ponto.instalacao ?? "-"})',
                    style: const TextStyle(
                      color: AppColors.background,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: AppColors.primaryText, width: 2),
            ),
            duration: const Duration(milliseconds: 1500),
          ),
        );
      }

      _focusFirstPending();
    } catch (e) {
      setState(() {
        state.errorMessage = 'Erro ao salvar: $e';
      });
    } finally {
      setState(() {
        state.isSaving = false;
      });
    }
  }

  Future<void> _coletarLeitura(PontoConsumo ponto, String grupoNome) async {
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
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
      if (mounted) {
        scaffoldMessenger.clearSnackBars();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: AppColors.background,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Leitura realizada! (Inst. ${ponto.instalacao ?? "-"})',
                    style: const TextStyle(
                      color: AppColors.background,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: AppColors.primaryText, width: 2),
            ),
            duration: const Duration(milliseconds: 1500),
          ),
        );
      }
    }
  }

  Widget _buildStandardListView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final entry in _groupedItems.entries) ...[
          _GroupHeader(nome: entry.key),
          const SizedBox(height: 6),
          for (final item in entry.value) ...[
            _PontoInternoCard(
              item: item,
              onTap: () => _coletarLeitura(item.resumo.ponto, entry.key),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildRoteiroListView() {
    final total = _roteiroStates.length;
    final completed = _roteiroStates
        .where((state) => _isItemColetado(state.item) || state.justSaved)
        .length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Progress bar at the top
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border.all(color: AppColors.primaryText, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Progresso do Roteiro:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryText,
                    ),
                  ),
                  Text(
                    'Coletados: $completed de $total',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: total > 0 ? completed / total : 0.0,
                backgroundColor: AppColors.background,
                color: AppColors.success,
                minHeight: 8,
              ),
              const SizedBox(height: 8),
              const Divider(
                height: 1,
                thickness: 1,
                color: AppColors.primaryText,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Mostrar concluídos no roteiro',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  SizedBox(
                    height: 28,
                    child: Switch(
                      value: _showConcluidosInRoteiro,
                      onChanged: (val) {
                        setState(() {
                          _showConcluidosInRoteiro = val;
                        });
                      },
                      activeColor: AppColors.primaryAction,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (completed == total && total > 0) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.success,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primaryText, width: 2),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: AppColors.background,
                  size: 28,
                ),
                SizedBox(width: 10),
                Text(
                  'Roteiro Preventivo Concluído!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.background,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        for (final state in _roteiroStates) ...[
          if (!_showConcluidosInRoteiro &&
              (_isItemColetado(state.item) || state.justSaved))
            const SizedBox.shrink()
          else ...[
            _buildRoteiroCard(state),
            const SizedBox(height: 10),
          ],
        ],
        const SizedBox(
          height: 80,
        ), // extra padding to avoid floating button overlap
      ],
    );
  }

  Widget _buildRoteiroCard(_RoteiroItemState state) {
    final ponto = state.item.resumo.ponto;
    final isColetado = _isItemColetado(state.item) || state.justSaved;
    final lastReading = state.item.resumo.ultimaLeitura?.valorLeitura;
    final readingVal = state.justSaved
        ? state.controller.text
        : (lastReading?.toString() ?? '-');

    if (isColetado) {
      // Collapsed Card for completed items
      return Card(
        color: AppColors.background,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.success, width: 2.0),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Inst. ${ponto.instalacao ?? "-"}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Med. ${ponto.numeroMedidor ?? "-"}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppColors.primaryText,
                      ),
                    ),
                    if (ponto.endereco != null && ponto.endereco!.isNotEmpty)
                      Text(
                        ponto.endereco!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.secondaryText,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Row(
                children: [
                  Text(
                    'Leitura: $readingVal',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'CONCLUÍDO',
                      style: TextStyle(
                        color: AppColors.background,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Expanded Work Card for pending items
    return Card(
      color: AppColors.background,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.primaryText, width: 2.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Inst. ${ponto.instalacao ?? "-"}',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Med. ${ponto.numeroMedidor ?? "-"}',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: AppColors.primaryText,
              ),
            ),
            if (ponto.endereco != null && ponto.endereco!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                ponto.endereco!,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.secondaryText,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                // Camera Button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _captureCardPhoto(state),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.primaryText,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: AppColors.background,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 28,
                        color: AppColors.primaryText,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // TextField Input
                Expanded(
                  child: TextFormField(
                    controller: state.controller,
                    focusNode: state.focusNode,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(5),
                    ],
                    onChanged: (text) {
                      setState(() {
                        state.errorMessage = null;
                      });
                    },
                    decoration: const InputDecoration(
                      hintText: 'Digite a leitura',
                      labelText: 'Leitura',
                      labelStyle: TextStyle(fontWeight: FontWeight.w700),
                      prefixIcon: Icon(Icons.pin_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Miniature preview
                if (state.fotoPath != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.file(
                      File(state.fotoPath!),
                      width: 54,
                      height: 54,
                      fit: BoxFit.cover,
                    ),
                  ),
              ],
            ),

            if (state.isOcrProcessing) ...[
              const SizedBox(height: 8),
              const Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primaryAction,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Processando OCR...',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryText,
                    ),
                  ),
                ],
              ),
            ],

            if (state.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                state.errorMessage!,
                style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],

            if (state.controller.text.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: state.isSaving
                      ? null
                      : () => _saveRoteiroLeitura(state),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: AppColors.background,
                    side: const BorderSide(
                      color: AppColors.primaryText,
                      width: 2,
                    ),
                    elevation: 0,
                  ),
                  icon: state.isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.background,
                          ),
                        )
                      : const Icon(Icons.check, size: 20),
                  label: const Text(
                    'Confirmar Leitura',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSelectedGroupInItems =
        _selectedGroupId == null ||
        _grupos.any((g) => g.id == _selectedGroupId);
    final dropdownValue = hasSelectedGroupInItems ? _selectedGroupId : null;

    return Scaffold(
      appBar: LeituraAppBar(
        title: 'Medidores Internos',
        actions: _flatItems.isEmpty
            ? null
            : [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Center(
                    child: SizedBox(
                      height: 36,
                      child: OutlinedButton.icon(
                        onPressed: _viewModel.isInRoteiroMode
                            ? _stopRoteiro
                            : _startRoteiro,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: _viewModel.isInRoteiroMode
                                ? AppColors.error
                                : AppColors.primaryText,
                            width: 2,
                          ),
                          backgroundColor: _viewModel.isInRoteiroMode
                              ? AppColors.error
                              : AppColors.background,
                          foregroundColor: _viewModel.isInRoteiroMode
                              ? AppColors.background
                              : AppColors.primaryText,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        icon: Icon(
                          _viewModel.isInRoteiroMode
                              ? Icons.stop
                              : Icons.play_arrow,
                          size: 18,
                        ),
                        label: Text(
                          _viewModel.isInRoteiroMode
                              ? 'Parar'
                              : 'Iniciar Roteiro',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (!_viewModel.isInRoteiroMode) ...[
              // Group Filter Dropdown
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: DropdownButtonFormField<int?>(
                  value: dropdownValue,
                  decoration: const InputDecoration(
                    labelText: 'Grupo (Região)',
                    prefixIcon: Icon(Icons.filter_list),
                  ),
                  dropdownColor: AppColors.background,
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Todos os grupos'),
                    ),
                    ..._grupos.map(
                      (g) => DropdownMenuItem<int?>(
                        value: g.id,
                        child: Text(g.nome),
                      ),
                    ),
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
            ],
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _groupedItems.isEmpty
                  ? const _EmptyState()
                  : _viewModel.isInRoteiroMode
                  ? _buildRoteiroListView()
                  : _buildStandardListView(),
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
                    if (ponto.instalacao != null &&
                        ponto.instalacao!.trim().isNotEmpty)
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
                    if (ponto.numeroMedidor != null &&
                        ponto.numeroMedidor!.trim().isNotEmpty)
                      Text(
                        'Med. ${ponto.numeroMedidor}',
                        style: const TextStyle(
                          color: AppColors.primaryText,
                          fontSize: 16,
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
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    if (ponto.endereco != null &&
                        ponto.endereco!.isNotEmpty) ...[
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isColetado ? AppColors.success : AppColors.warning,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isColetado ? 'COLETADO' : 'PENDENTE',
                      style: TextStyle(
                        color: isColetado
                            ? AppColors.background
                            : AppColors.primaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (leitura != null && ponto.isComposto)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '03: ${leitura.valorLeitura}',
                          style: const TextStyle(
                            color: AppColors.primaryText,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '103: ${leitura.valorProducao ?? "-"}',
                          style: const TextStyle(
                            color: AppColors.primaryText,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      leitura == null
                          ? 'Sem leitura'
                          : isColetado
                          ? 'Leitura: ${leitura.valorLeitura}'
                          : 'Última: ${leitura.valorLeitura}',
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
    if (item.resumo.ponto.isDesabitado) return true;
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
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Nenhum medidor interno pendente.',
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

class _RoteiroItemState {
  final PontoInternoResumo item;
  final TextEditingController controller;
  final FocusNode focusNode;
  String? fotoPath;
  String? ocrRawText;
  bool isSaving = false;
  bool isOcrProcessing = false;
  bool justSaved = false;
  String? errorMessage;

  _RoteiroItemState({
    required this.item,
    required this.controller,
    required this.focusNode,
  });

  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}
