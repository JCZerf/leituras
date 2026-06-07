import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/grupo.dart';
import '../services/camera_service.dart';
import '../models/ponto_consumo.dart';
import '../repositories/grupo_repository.dart';
import '../repositories/historico_leitura_repository.dart';
import '../repositories/ponto_consumo_repository.dart';
import '../theme/app_colors.dart';
import '../viewmodels/leitura_form_view_model.dart';
import '../viewmodels/leitura_validators.dart';
import 'leitura_app_bar.dart';

class LeituraFormView extends StatefulWidget {
  const LeituraFormView({
    super.key,
    required this.grupo,
    required this.grupoRepository,
    required this.pontoConsumoRepository,
    required this.historicoLeituraRepository,
    this.ponto,
  });

  final Grupo grupo;
  final PontoConsumo? ponto;
  final GrupoRepository grupoRepository;
  final PontoConsumoRepository pontoConsumoRepository;
  final HistoricoLeituraRepository historicoLeituraRepository;

  @override
  State<LeituraFormView> createState() => _LeituraFormViewState();
}

class _LeituraFormViewState extends State<LeituraFormView> {
  final _formKey = GlobalKey<FormState>();
  late final LeituraFormViewModel _viewModel;
  late final CameraService _cameraService;
  late final TextEditingController _instalacaoController;
  late final TextEditingController _numeroMedidorController;
  late final TextEditingController _leituraController;
  late final TextEditingController _enderecoController;
  late final TextEditingController _fotoDescricaoController;
  bool _isSaving = false;
  String? _errorMessage;
  String? _fotoPath;
  bool _saved = false;
  bool _isInterno = false;

  bool get _isNovoLancamento => widget.ponto != null;

  @override
  void initState() {
    super.initState();
    final ponto = widget.ponto;
    _viewModel = LeituraFormViewModel(
      grupoRepository: widget.grupoRepository,
      pontoConsumoRepository: widget.pontoConsumoRepository,
      historicoLeituraRepository: widget.historicoLeituraRepository,
    );
    _cameraService = CameraService();
    _instalacaoController = TextEditingController(
      text: ponto?.instalacao ?? '',
    );
    _numeroMedidorController = TextEditingController(
      text: ponto?.numeroMedidor ?? '',
    );
    _leituraController = TextEditingController();
    _enderecoController = TextEditingController(text: ponto?.endereco ?? '');
    _fotoDescricaoController = TextEditingController();
  }

  @override
  void dispose() {
    _instalacaoController.dispose();
    _numeroMedidorController.dispose();
    _leituraController.dispose();
    _enderecoController.dispose();
    _fotoDescricaoController.dispose();
    if (!_saved && _fotoPath != null) {
      _cameraService.deletePhoto(_fotoPath!);
    }
    super.dispose();
  }

  Future<void> _takePhoto() async {
    try {
      final path = await _cameraService.capturePhoto();
      if (path != null) {
        setState(() {
          _fotoPath = path;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro ao capturar foto: $e';
      });
    }
  }

  Future<void> _deletePhoto() async {
    if (_fotoPath != null) {
      try {
        await _cameraService.deletePhoto(_fotoPath!);
      } catch (_) {}
      setState(() {
        _fotoPath = null;
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _errorMessage = _isNovoLancamento
          ? null
          : LeituraValidators.identificadores(
              instalacao: _instalacaoController.text,
              numeroMedidor: _numeroMedidorController.text,
            );
    });

    if (!(_formKey.currentState?.validate() ?? false) ||
        _errorMessage != null) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      if (_isNovoLancamento) {
        await _viewModel.addHistorico(
          pontoConsumoId: widget.ponto!.id,
          leitura: _leituraController.text,
          fotoPath: _fotoPath,
          fotoDescricao: _fotoDescricaoController.text,
        );
      } else {
        await _viewModel.createPontoComLeitura(
          grupoId: widget.grupo.id,
          instalacao: _instalacaoController.text,
          numeroMedidor: _numeroMedidorController.text,
          leitura: _leituraController.text,
          endereco: _enderecoController.text,
          fotoPath: _fotoPath,
          fotoDescricao: _fotoDescricaoController.text,
          isInterno: _isInterno,
        );
      }
      _saved = true;
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      setState(() {
        _errorMessage = error is ArgumentError
            ? error.message?.toString()
            : 'Nao foi possivel salvar o lancamento.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: LeituraAppBar(
        title: _isNovoLancamento ? 'Nova leitura' : 'Cadastrar medidor',
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _GrupoBanner(nome: widget.grupo.nome),
              const SizedBox(height: 16),
              if (_isNovoLancamento)
                _PontoBanner(ponto: widget.ponto!)
              else ...[
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
                    helperText: 'Importante: Detalhe bem o local (ex: Apto 302, Fundo do galpao trancado)',
                    helperMaxLines: 2,
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text(
                    'Este medidor e INTERNO?',
                    style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.primaryText),
                  ),
                  subtitle: const Text(
                    'Exige agendamento / contato previo',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  value: _isInterno,
                  onChanged: (val) {
                    setState(() {
                      _isInterno = val;
                    });
                  },
                  activeColor: AppColors.primaryAction,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _leituraController,
                decoration: const InputDecoration(
                  labelText: 'Valor da leitura',
                  prefixIcon: Icon(Icons.pin_outlined),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(5),
                ],
                validator: (value) => LeituraValidators.leitura(value ?? ''),
              ),
              const SizedBox(height: 16),
              if (_fotoPath == null)
                OutlinedButton.icon(
                  onPressed: _takePhoto,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Tirar Foto do Relogio'),
                )
              else
                Container(
                  height: 100,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.primaryText, width: 1.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(6)),
                        child: Image.file(
                          File(_fotoPath!),
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Foto capturada',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Excluir foto',
                        onPressed: _deletePhoto,
                        icon: const Icon(Icons.delete_outline, color: AppColors.error),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _fotoDescricaoController,
                decoration: const InputDecoration(
                  labelText: 'Descricao da foto',
                  prefixIcon: Icon(Icons.image_outlined),
                ),
                maxLines: 3,
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
                label: Text(
                  _isNovoLancamento ? 'Salvar leitura' : 'Salvar medidor',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GrupoBanner extends StatelessWidget {
  const _GrupoBanner({required this.nome});

  final String nome;

  @override
  Widget build(BuildContext context) {
    return _Banner(
      icon: Icons.folder_outlined,
      title: nome,
      subtitle: 'Grupo selecionado',
    );
  }
}

class _PontoBanner extends StatelessWidget {
  const _PontoBanner({required this.ponto});

  final PontoConsumo ponto;

  @override
  Widget build(BuildContext context) {
    final identificadores = [
      if (ponto.instalacao != null) 'Instalacao ${ponto.instalacao}',
      if (ponto.numeroMedidor != null) 'Medidor ${ponto.numeroMedidor}',
    ].join(' | ');

    return _Banner(
      icon: Icons.speed_outlined,
      title: identificadores,
      subtitle: ponto.endereco ?? 'Medidor cadastrado',
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primaryText, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: AppColors.secondaryText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
