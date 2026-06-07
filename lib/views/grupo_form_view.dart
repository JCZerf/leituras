import 'package:flutter/material.dart';

import '../models/grupo.dart';
import '../repositories/grupo_repository.dart';
import '../theme/app_colors.dart';
import '../viewmodels/leitura_validators.dart';
import 'leitura_app_bar.dart';

/// Form for creating or editing a [Grupo].
///
/// When [grupo] is null the form creates a new group.
/// When [grupo] is provided the form edits the existing group.
class GrupoFormView extends StatefulWidget {
  const GrupoFormView({
    super.key,
    required this.grupoRepository,
    this.grupo,
  });

  final GrupoRepository grupoRepository;

  /// If non-null the form opens in edit mode.
  final Grupo? grupo;

  @override
  State<GrupoFormView> createState() => _GrupoFormViewState();
}

class _GrupoFormViewState extends State<GrupoFormView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomeController;
  late final TextEditingController _descricaoController;
  bool _isSaving = false;
  String? _errorMessage;

  bool get _isEditing => widget.grupo != null;

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(
      text: widget.grupo?.nome ?? '',
    );
    _descricaoController = TextEditingController(
      text: widget.grupo?.descricao ?? '',
    );
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      if (_isEditing) {
        final updated = widget.grupo!.copyWith(
          nome: _nomeController.text.trim(),
          descricao: _optional(_descricaoController.text),
        );
        await widget.grupoRepository.update(updated);
      } else {
        await widget.grupoRepository.insert(
          Grupo(
            nome: _nomeController.text.trim(),
            descricao: _optional(_descricaoController.text),
            dataCriacao: DateTime.now(),
          ),
        );
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      setState(() {
        _errorMessage = _isEditing
            ? 'Nao foi possivel salvar as alteracoes.'
            : 'Nao foi possivel criar o grupo.';
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
      appBar: LeituraAppBar(
        title: _isEditing ? 'Editar grupo' : 'Novo grupo',
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome do grupo',
                  prefixIcon: Icon(Icons.folder_outlined),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) => LeituraValidators.nomeGrupo(value ?? ''),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descricaoController,
                decoration: const InputDecoration(
                  labelText: 'Descricao',
                  prefixIcon: Icon(Icons.notes_outlined),
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
                label: Text(_isEditing ? 'Salvar alteracoes' : 'Salvar grupo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
