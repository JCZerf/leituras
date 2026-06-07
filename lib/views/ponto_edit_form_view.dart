import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/ponto_consumo.dart';
import '../repositories/ponto_consumo_repository.dart';
import '../theme/app_colors.dart';
import '../viewmodels/leitura_validators.dart';
import 'leitura_app_bar.dart';

/// Form to edit the fixed fields of a consumption point (instalação,
/// número do medidor, endereço). Does NOT create a new reading entry.
class PontoEditFormView extends StatefulWidget {
  const PontoEditFormView({
    super.key,
    required this.ponto,
    required this.pontoConsumoRepository,
  });

  final PontoConsumo ponto;
  final PontoConsumoRepository pontoConsumoRepository;

  @override
  State<PontoEditFormView> createState() => _PontoEditFormViewState();
}

class _PontoEditFormViewState extends State<PontoEditFormView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _instalacaoController;
  late final TextEditingController _numeroMedidorController;
  late final TextEditingController _enderecoController;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _instalacaoController = TextEditingController(
      text: widget.ponto.instalacao ?? '',
    );
    _numeroMedidorController = TextEditingController(
      text: widget.ponto.numeroMedidor ?? '',
    );
    _enderecoController = TextEditingController(
      text: widget.ponto.endereco ?? '',
    );
  }

  @override
  void dispose() {
    _instalacaoController.dispose();
    _numeroMedidorController.dispose();
    _enderecoController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final idError = LeituraValidators.identificadores(
      instalacao: _instalacaoController.text,
      numeroMedidor: _numeroMedidorController.text,
    );
    setState(() {
      _errorMessage = idError;
    });

    if (!(_formKey.currentState?.validate() ?? false) || idError != null) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final updated = widget.ponto.copyWith(
        instalacao: _optional(_instalacaoController.text),
        numeroMedidor: _optional(_numeroMedidorController.text),
        endereco: _optional(_enderecoController.text),
      );
      await widget.pontoConsumoRepository.update(updated);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      setState(() {
        _errorMessage = 'Nao foi possivel salvar as alteracoes.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String? _optional(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const LeituraAppBar(title: 'Editar medidor'),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _instalacaoController,
                decoration: const InputDecoration(
                  labelText: 'Instalacao',
                  prefixIcon: Icon(Icons.home_work_outlined),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _numeroMedidorController,
                decoration: const InputDecoration(
                  labelText: 'Numero do medidor',
                  prefixIcon: Icon(Icons.speed_outlined),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
                ],
                textInputAction: TextInputAction.next,
                validator: (value) =>
                    LeituraValidators.numeroMedidor(value ?? ''),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _enderecoController,
                decoration: const InputDecoration(
                  labelText: 'Endereco',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Salvar alteracoes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
