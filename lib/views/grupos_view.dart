import 'package:flutter/material.dart';

import '../models/grupo.dart';
import '../repositories/grupo_repository.dart';
import '../repositories/ponto_consumo_repository.dart';
import '../theme/app_colors.dart';
import '../viewmodels/app_state.dart';
import '../widgets/app_action_sheet.dart';
import 'grupo_form_view.dart';
import 'leitura_app_bar.dart';

class GruposView extends StatefulWidget {
  const GruposView({
    super.key,
    required this.appState,
    required this.grupoRepository,
    required this.pontoConsumoRepository,
  });

  final AppState appState;
  final GrupoRepository grupoRepository;
  final PontoConsumoRepository pontoConsumoRepository;

  @override
  State<GruposView> createState() => _GruposViewState();
}

class _GruposViewState extends State<GruposView> {
  final _searchController = TextEditingController();
  List<Grupo> _grupos = const [];
  bool _isLoading = true;
  String _query = '';

  List<Grupo> get _filteredGroups {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return _grupos;
    }
    return _grupos
        .where((grupo) => grupo.nome.toLowerCase().contains(query))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    setState(() {
      _isLoading = true;
    });

    final grupos = await widget.grupoRepository.findAll();
    if (!mounted) {
      return;
    }
    setState(() {
      _grupos = grupos;
      _isLoading = false;
    });
  }

  Future<void> _createGroup() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => GrupoFormView(grupoRepository: widget.grupoRepository),
      ),
    );
    if (created == true) {
      await _loadGroups();
    }
  }

  Future<void> _editGroup(Grupo grupo) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => GrupoFormView(
          grupoRepository: widget.grupoRepository,
          grupo: grupo,
        ),
      ),
    );
    if (saved == true) {
      await _loadGroups();
    }
  }

  Future<void> _deleteGroup(Grupo grupo) async {
    // Check if group has meters linked via ON DELETE RESTRICT.
    final hasMedidores = await widget.pontoConsumoRepository.existsByGrupoId(
      grupo.id!,
    );

    if (!mounted) return;

    if (hasMedidores) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Exclusao bloqueada'),
          content: const Text(
            'Nao e possivel excluir um grupo com medidores ativos. '
            'Remova os medidores antes de excluir o grupo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Entendi'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir grupo'),
        content: Text('Deseja excluir o grupo "${grupo.nome}"?'),
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

    try {
      await widget.grupoRepository.delete(grupo.id!);
      // If the deleted group was selected, clear the selection.
      if (widget.appState.selectedGroupId == grupo.id) {
        widget.appState.clearSelectedGroup();
      }
      await _loadGroups();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ArgumentError
                ? error.message.toString()
                : 'Erro ao excluir o grupo.',
          ),
        ),
      );
    }
  }

  void _showActions(Grupo grupo) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (ctx) => AppActionSheet(
        title: grupo.nome,
        icon: Icons.folder_outlined,
        subtitle: 'Acoes do grupo',
        actions: [
          AppActionSheetAction(
            label: 'Editar cadastro',
            subtitle: 'Alterar nome e descricao do grupo.',
            icon: Icons.edit_outlined,
            onPressed: () {
              Navigator.of(ctx).pop();
              _editGroup(grupo);
            },
          ),
          AppActionSheetAction(
            label: 'Excluir grupo',
            subtitle: 'Remove o grupo quando nao houver medidores vinculados.',
            icon: Icons.delete_outline,
            isDestructive: true,
            onPressed: () {
              Navigator.of(ctx).pop();
              _deleteGroup(grupo);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grupos = _filteredGroups;

    return Scaffold(
      appBar: LeituraAppBar(
        title: 'Grupos',
        actions: [
          IconButton(
            tooltip: 'Criar grupo',
            onPressed: _createGroup,
            icon: const Icon(Icons.create_new_folder_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_grupos',
        onPressed: _createGroup,
        backgroundColor: AppColors.primaryAction,
        foregroundColor: AppColors.background,
        icon: const Icon(Icons.add),
        label: const Text('Grupo'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _query = value;
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'Buscar grupo',
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
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (grupos.isEmpty)
                    _EmptyGroups(hasSearch: _query.trim().isNotEmpty)
                  else
                    ...grupos.map(
                      (grupo) => _GroupTile(
                        grupo: grupo,
                        isSelected: widget.appState.selectedGroupId == grupo.id,
                        onTap: () => widget.appState.selectGroup(grupo),
                        onLongPress: () => _showActions(grupo),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({
    required this.grupo,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  final Grupo grupo;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.background,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? AppColors.primaryAction : AppColors.primaryText,
          width: isSelected ? 2 : 1.5,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        onLongPress: onLongPress,
        minVerticalPadding: 8,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Icon(
          isSelected ? Icons.check_circle : Icons.folder_outlined,
          color: isSelected ? AppColors.primaryAction : AppColors.primaryText,
        ),
        title: Text(
          grupo.nome,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.primaryText,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: grupo.descricao == null
            ? null
            : Text(
                grupo.descricao!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 13,
                ),
              ),
        trailing: IconButton(
          tooltip: 'Mais opcoes',
          icon: const Icon(Icons.more_vert),
          onPressed: onLongPress,
        ),
      ),
    );
  }
}

class _EmptyGroups extends StatelessWidget {
  const _EmptyGroups({required this.hasSearch});

  final bool hasSearch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primaryText, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        hasSearch ? 'Nenhum grupo encontrado.' : 'Nenhum grupo cadastrado.',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }
}
