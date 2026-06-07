import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../viewmodels/estimador_view_model.dart';
import 'leitura_app_bar.dart';

class EstimadorView extends StatefulWidget {
  const EstimadorView({super.key, this.initialReadings});

  final List<int>? initialReadings;

  @override
  State<EstimadorView> createState() => _EstimadorViewState();
}

class _EstimadorViewState extends State<EstimadorView> {
  late final EstimadorViewModel _viewModel;
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _viewModel = EstimadorViewModel()..addListener(_handleViewModelChanged);
    if (widget.initialReadings != null) {
      _viewModel.loadReadings(widget.initialReadings!);
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_handleViewModelChanged);
    _viewModel.dispose();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleAdd() {
    setState(() {
      _errorMessage = null;
    });
    final error = _viewModel.validateAndAddReading(_controller.text);
    if (error != null) {
      setState(() {
        _errorMessage = error;
      });
    } else {
      _controller.clear();
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final readings = _viewModel.readings;
    final avg = _viewModel.averageConsumption;
    final next = _viewModel.estimatedNextReading;

    return Scaffold(
      appBar: const LeituraAppBar(title: 'Estimador de Consumo'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Form Input
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primaryText, width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Adicionar Leitura',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: _controller,
                                focusNode: _focusNode,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: 'Ex: 1234',
                                  errorText: _errorMessage,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                ),
                                onSubmitted: (_) => _handleAdd(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _handleAdd,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(80, 48),
                          ),
                          child: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // List Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Sequência de Leituras',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryText,
                    ),
                  ),
                  if (readings.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _errorMessage = null;
                        });
                        _viewModel.clear();
                      },
                      child: const Text(
                        'Limpar',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // List of Readings
              if (readings.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.secondaryText, width: 1.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Nenhuma leitura adicionada.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondaryText,
                    ),
                  ),
                )
              else
                Column(
                  children: [
                    for (int i = 0; i < readings.length; i++) ...[
                      _ReadingTile(
                        index: i,
                        value: readings[i],
                        onRemove: () {
                          setState(() {
                            _errorMessage = null;
                          });
                          _viewModel.removeReadingAt(i);
                        },
                      ),
                      const SizedBox(height: 6),
                    ],
                  ],
                ),
              const SizedBox(height: 24),
              // Calculation Results Section
              _ResultsCard(
                readingsCount: readings.length,
                averageConsumption: avg,
                estimatedNextReading: next,
                hasAnomaly: _viewModel.hasConsumptionAnomaly,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadingTile extends StatelessWidget {
  const _ReadingTile({
    required this.index,
    required this.value,
    required this.onRemove,
  });

  final int index;
  final int value;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primaryText, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Período ${index + 1}:  $value',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryText,
            ),
          ),
          IconButton(
            tooltip: 'Remover leitura',
            onPressed: onRemove,
            icon: const Icon(
              Icons.delete_outline,
              color: AppColors.error,
              size: 22,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class _ResultsCard extends StatelessWidget {
  const _ResultsCard({
    required this.readingsCount,
    required this.averageConsumption,
    required this.estimatedNextReading,
    required this.hasAnomaly,
  });

  final int readingsCount;
  final double? averageConsumption;
  final int? estimatedNextReading;
  final bool hasAnomaly;

  @override
  Widget build(BuildContext context) {
    final hasEnough = readingsCount >= 2;
    final accentColor = hasEnough
        ? (hasAnomaly ? AppColors.error : AppColors.primaryAction)
        : AppColors.secondaryText;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: hasEnough
            ? (hasAnomaly
                ? AppColors.error.withValues(alpha: 0.05)
                : AppColors.primaryAction.withValues(alpha: 0.05))
            : Colors.transparent,
        border: Border.all(
          color: accentColor,
          width: 2.5,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resultado Estimado',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 12),
          if (hasEnough && hasAnomaly) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                border: Border.all(color: AppColors.error, width: 2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '⚠️ Variação atípica detectada no último período!',
                      style: TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (!hasEnough)
            const Text(
              'Insira pelo menos 2 leituras sequenciais para visualizar a estimativa de consumo.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.secondaryText,
              ),
            )
          else ...[
            const Text(
              'Consumo Médio por Período:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.secondaryText,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${averageConsumption!.toStringAsFixed(1)} kWh',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: hasAnomaly ? AppColors.error : AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Próxima Leitura Estimada:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.secondaryText,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$estimatedNextReading',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: hasAnomaly ? AppColors.error : AppColors.primaryText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
