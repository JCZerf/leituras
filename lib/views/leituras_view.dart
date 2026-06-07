import 'package:flutter/material.dart';

import '../models/historico_leitura.dart';
import '../models/ponto_consumo.dart';
import '../models/ponto_consumo_resumo.dart';
import '../repositories/grupo_repository.dart';
import '../repositories/historico_leitura_repository.dart';
import '../repositories/ponto_consumo_repository.dart';
import '../theme/app_colors.dart';
import '../viewmodels/app_state.dart';
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
  List<PontoConsumoResumo> _pontos = const [];
  bool _isLoading = false;
  int? _loadedGroupId;

  @override
  void initState() {
    super.initState();
    widget.appState.addListener(_handleAppStateChanged);
    _loadSelectedGroup();
  }

  @override
  void dispose() {
    widget.appState.removeListener(_handleAppStateChanged);
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

    return Scaffold(
      appBar: AppBar(title: const Text('Leituras')),
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
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  _SelectedGroupHeader(groupName: grupo.nome),
                  const SizedBox(height: 10),
                  if (_pontos.isEmpty)
                    const _EmptyMeters()
                  else
                    ..._pontos.map(
                      (resumo) => _MeterTile(
                        resumo: resumo,
                        onTap: () => _openDetail(resumo.ponto),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _SelectedGroupHeader extends StatelessWidget {
  const _SelectedGroupHeader({required this.groupName});

  final String groupName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primaryText, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.folder_outlined),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              groupName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
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
    final primaryLabel = ponto.instalacao != null
        ? 'Instalacao: ${ponto.instalacao}'
        : 'Medidor: ${ponto.numeroMedidor ?? '-'}';

    return Card(
      color: AppColors.background,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.primaryText, width: 1.5),
      ),
      child: ListTile(
        onTap: onTap,
        dense: true,
        visualDensity: VisualDensity.compact,
        minVerticalPadding: 4,
        contentPadding: const EdgeInsets.only(left: 10, right: 4),
        title: Text(
          primaryLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.primaryText,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: ponto.instalacao != null && ponto.numeroMedidor != null
            ? Text(
                'Medidor: ${ponto.numeroMedidor}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              )
            : null,
        trailing: _ReadingTrailing(leitura: leitura),
      ),
    );
  }
}

class _ReadingTrailing extends StatelessWidget {
  const _ReadingTrailing({required this.leitura});

  final HistoricoLeitura? leitura;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          leitura == null ? 'Sem leitura' : 'Leitura: ${leitura!.valorLeitura}',
          style: const TextStyle(
            color: AppColors.primaryText,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 2),
        const Icon(
          Icons.chevron_right,
          color: AppColors.secondaryText,
          size: 22,
        ),
      ],
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
