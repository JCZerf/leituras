import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/grupo.dart';
import 'foto_viewer_view.dart';
import '../models/historico_leitura.dart';
import '../models/ponto_consumo.dart';
import '../repositories/grupo_repository.dart';
import '../repositories/historico_leitura_repository.dart';
import '../repositories/ponto_consumo_repository.dart';
import '../theme/app_colors.dart';
import '../viewmodels/leitura_validators.dart';
import '../widgets/app_modal.dart';
import 'estimador_view.dart';
import 'leitura_app_bar.dart';
import 'leitura_form_view.dart';

class LeituraDetailView extends StatefulWidget {
  const LeituraDetailView({
    super.key,
    required this.grupo,
    required this.ponto,
    required this.grupoRepository,
    required this.pontoConsumoRepository,
    required this.historicoLeituraRepository,
  });

  final Grupo grupo;
  final PontoConsumo ponto;
  final GrupoRepository grupoRepository;
  final PontoConsumoRepository pontoConsumoRepository;
  final HistoricoLeituraRepository historicoLeituraRepository;

  @override
  State<LeituraDetailView> createState() => _LeituraDetailViewState();
}

class _LeituraDetailViewState extends State<LeituraDetailView> {
  late Future<List<HistoricoLeitura>> _historicoFuture;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _historicoFuture = _loadHistorico();
  }

  Future<List<HistoricoLeitura>> _loadHistorico() {
    return widget.historicoLeituraRepository.findByPontoConsumoId(
      widget.ponto.id!,
    );
  }

  Future<void> _novoLancamento() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LeituraFormView(
          grupo: widget.grupo,
          ponto: widget.ponto,
          grupoRepository: widget.grupoRepository,
          pontoConsumoRepository: widget.pontoConsumoRepository,
          historicoLeituraRepository: widget.historicoLeituraRepository,
        ),
      ),
    );
    if (changed == true && mounted) {
      _changed = true;
      setState(() {
        _historicoFuture = _loadHistorico();
      });
    }
  }

  void _refreshHistorico() {
    _changed = true;
    setState(() {
      _historicoFuture = _loadHistorico();
    });
  }

  Future<void> _editHistorico(HistoricoLeitura historico) async {
    final leituraController = TextEditingController(
      text: historico.valorLeitura.toString(),
    );
    final producaoController = TextEditingController(
      text: historico.valorProducao?.toString() ?? '',
    );
    final formKey = GlobalKey<FormState>();

    final updated = await showDialog<HistoricoLeitura>(
      context: context,
      builder: (ctx) => AppModal(
        title: 'Editar leitura',
        icon: Icons.edit_outlined,
        subtitle: 'Corrija apenas o valor lancado no historico.',
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: leituraController,
                decoration: InputDecoration(
                  labelText: widget.ponto.isComposto
                      ? 'Leitura 03 - Consumo'
                      : 'Valor da leitura',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(5),
                ],
                validator: (value) => LeituraValidators.leitura(value ?? ''),
              ),
              if (widget.ponto.isComposto) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: producaoController,
                  decoration: const InputDecoration(
                    labelText: 'Leitura 103 - Producao',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(5),
                  ],
                  validator: (value) => LeituraValidators.leitura(value ?? ''),
                ),
              ],
            ],
          ),
        ),
        actions: [
          AppModalAction(
            label: 'Cancelar',
            icon: Icons.close,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          AppModalAction(
            label: 'Salvar',
            icon: Icons.check,
            isPrimary: true,
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) {
                return;
              }
              Navigator.of(ctx).pop(
                HistoricoLeitura(
                  id: historico.id,
                  pontoConsumoId: historico.pontoConsumoId,
                  valorLeitura: int.parse(leituraController.text.trim()),
                  valorProducao: widget.ponto.isComposto
                      ? int.parse(producaoController.text.trim())
                      : null,
                  dataLeitura: historico.dataLeitura,
                  fotoPath: historico.fotoPath,
                  fotoDescricao: historico.fotoDescricao,
                ),
              );
            },
          ),
        ],
      ),
    );

    leituraController.dispose();
    producaoController.dispose();

    if (updated == null || !mounted) {
      return;
    }

    await widget.historicoLeituraRepository.update(updated);
    if (!mounted) {
      return;
    }
    _refreshHistorico();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Leitura atualizada.')),
    );
  }

  Future<void> _deleteHistorico(HistoricoLeitura historico) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppModal(
        title: 'Excluir leitura',
        icon: Icons.delete_outline,
        subtitle: 'O cadastro do medidor sera mantido.',
        content: Text(
          widget.ponto.isComposto
              ? '03: ${historico.valorLeitura}\n103: ${historico.valorProducao ?? "-"}'
              : 'Leitura: ${historico.valorLeitura}',
          style: const TextStyle(
            color: AppColors.primaryText,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          AppModalAction(
            label: 'Cancelar',
            icon: Icons.close,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          AppModalAction(
            label: 'Excluir',
            icon: Icons.delete_outline,
            onPressed: () => Navigator.of(ctx).pop(true),
            isPrimary: true,
            isDestructive: true,
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    await widget.historicoLeituraRepository.delete(historico.id!);
    if (historico.fotoPath != null) {
      final file = File(historico.fotoPath!);
      if (await file.exists()) {
        await file.delete();
      }
    }
    if (!mounted) {
      return;
    }
    _refreshHistorico();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Leitura excluida.')),
    );
  }

  Future<bool> _onWillPop() async {
    Navigator.of(context).pop(_changed);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _onWillPop();
        }
      },
      child: Scaffold(
        appBar: LeituraAppBar(
          title: 'Histórico',
          leading: IconButton(
            tooltip: 'Voltar',
            onPressed: _onWillPop,
            icon: const Icon(Icons.arrow_back),
          ),
          actions: [
            IconButton(
              tooltip: 'Nova leitura',
              onPressed: _novoLancamento,
              icon: const Icon(Icons.add_chart_outlined),
            ),
          ],
        ),
        body: SafeArea(
          child: FutureBuilder<List<HistoricoLeitura>>(
            future: _historicoFuture,
            builder: (context, snapshot) {
              final historico = snapshot.data ?? const <HistoricoLeitura>[];

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _PontoHeader(grupo: widget.grupo, ponto: widget.ponto),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _novoLancamento,
                    icon: const Icon(Icons.add),
                    label: const Text('Nova leitura'),
                  ),
                  if (historico.length >= 2) ...[
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        final values = historico
                            .take(6)
                            .map((h) => h.valorLeitura)
                            .toList()
                            .reversed
                            .toList();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                EstimadorView(initialReadings: values),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.background,
                        foregroundColor: AppColors.primaryAction,
                        side: const BorderSide(
                          color: AppColors.primaryAction,
                          width: 2,
                        ),
                      ),
                      icon: const Icon(Icons.show_chart),
                      label: const Text('Ver Estimativa de Consumo'),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    'Linha do tempo',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.primaryText,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Center(child: CircularProgressIndicator())
                  else if (historico.isEmpty)
                    const _EmptyTimeline()
                  else
                    ...historico.map(
                      (h) => _TimelineItem(
                        h,
                        ponto: widget.ponto,
                        onEdit: () => _editHistorico(h),
                        onDelete: () => _deleteHistorico(h),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PontoHeader extends StatelessWidget {
  const _PontoHeader({required this.grupo, required this.ponto});

  final Grupo grupo;
  final PontoConsumo ponto;

  @override
  Widget build(BuildContext context) {
    final fields = [
      _DetailField('Grupo', grupo.nome),
      _DetailField('Instalacao', ponto.instalacao),
      _DetailField('Numero do medidor', ponto.numeroMedidor),
      _DetailField('Endereco', ponto.endereco),
      _DetailField('Tipo', ponto.isComposto ? 'Composto 03/103' : 'Simples'),
      _DetailField('Situacao', ponto.isDesabitado ? 'Desabitado' : null),
    ].where((field) => field.value != null && field.value!.isNotEmpty);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primaryText, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Medidor',
            style: TextStyle(
              color: AppColors.primaryText,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          ...fields.map((field) => _DetailRow(field: field)),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem(
    this.historico, {
    required this.ponto,
    required this.onEdit,
    required this.onDelete,
  });

  final HistoricoLeitura historico;
  final PontoConsumo ponto;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  Future<void> _share(BuildContext context) async {
    final dateStr = _formatDate(historico.dataLeitura);
    final text =
        '${_readingShareText()}\n'
        'Data: $dateStr\n'
        'Instalacao: ${ponto.instalacao ?? "-"}\n'
        'Medidor: ${ponto.numeroMedidor ?? "-"}';

    try {
      if (historico.fotoPath != null) {
        await Share.shareXFiles([XFile(historico.fotoPath!)], text: text);
      } else {
        await Share.share(text);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao compartilhar: $e')));
      }
    }
  }

  String _readingShareText() {
    if (!ponto.isComposto) {
      return 'Leitura: ${historico.valorLeitura}';
    }
    return '03 Consumo: ${historico.valorLeitura}\n'
        '103 Producao: ${historico.valorProducao ?? "-"}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primaryText, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.timeline_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ponto.isComposto
                                ? '03: ${historico.valorLeitura}'
                                : historico.valorLeitura.toString(),
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryText,
                                ),
                          ),
                          if (ponto.isComposto) ...[
                            const SizedBox(height: 4),
                            Text(
                              '103: ${historico.valorProducao ?? "-"}',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryText,
                                  ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            _formatDate(historico.dataLeitura),
                            style: const TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (historico.fotoDescricao != null &&
                              historico.fotoDescricao!.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              historico.fotoDescricao!,
                              style: const TextStyle(
                                color: AppColors.primaryText,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (historico.fotoPath != null) ...[
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => FotoViewerView(
                                fotoPath: historico.fotoPath!,
                                descricao: historico.fotoDescricao,
                                shareText:
                                    '${_readingShareText()}\n'
                                    'Data: ${_formatDate(historico.dataLeitura)}\n'
                                    'Instalacao: ${ponto.instalacao ?? "-"}',
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppColors.primaryText,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6.5),
                            child: Image.file(
                              File(historico.fotoPath!),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.broken_image_outlined,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const Divider(
            height: 24,
            thickness: 1.5,
            color: AppColors.primaryText,
          ),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 4,
            runSpacing: 4,
            children: [
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text(
                  'Editar',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  foregroundColor: AppColors.primaryText,
                ),
              ),
              TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text(
                  'Excluir',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  foregroundColor: AppColors.error,
                ),
              ),
              TextButton.icon(
                onPressed: () => _share(context),
                icon: const Icon(Icons.share_outlined, size: 18),
                label: const Text(
                  'Compartilhar',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  foregroundColor: AppColors.primaryText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} '
        '${two(value.hour)}:${two(value.minute)}';
  }
}

class _EmptyTimeline extends StatelessWidget {
  const _EmptyTimeline();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primaryText, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'Nenhuma leitura registrada para este medidor.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _DetailField {
  const _DetailField(this.label, this.value);

  final String label;
  final String? value;
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.field});

  final _DetailField field;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            field.label,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            field.value!,
            style: const TextStyle(
              color: AppColors.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
