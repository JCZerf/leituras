import 'package:flutter/material.dart';

import '../models/grupo.dart';
import '../models/ponto_consumo.dart';
import '../models/ponto_consumo_resumo.dart';
import '../repositories/grupo_repository.dart';
import '../repositories/historico_leitura_repository.dart';
import '../repositories/ponto_consumo_repository.dart';
import '../theme/app_colors.dart';
import '../viewmodels/home_view_model.dart';
import 'grupo_form_view.dart';
import 'leitura_detail_view.dart';
import 'leitura_form_view.dart';

class HomeView extends StatefulWidget {
  const HomeView({
    super.key,
    required this.grupoRepository,
    required this.pontoConsumoRepository,
    required this.historicoLeituraRepository,
  });

  final GrupoRepository grupoRepository;
  final PontoConsumoRepository pontoConsumoRepository;
  final HistoricoLeituraRepository historicoLeituraRepository;

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late final HomeViewModel _viewModel;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _viewModel = HomeViewModel(
      grupoRepository: widget.grupoRepository,
      pontoConsumoRepository: widget.pontoConsumoRepository,
    )..addListener(_onViewModelChanged);
    _viewModel.load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _viewModel
      ..removeListener(_onViewModelChanged)
      ..dispose();
    super.dispose();
  }

  void _onViewModelChanged() {
    if (mounted) {
      if (_searchController.text != _viewModel.searchQuery) {
        _searchController.text = _viewModel.searchQuery;
      }
      setState(() {});
    }
  }

  Future<void> _openGrupoForm() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => GrupoFormView(viewModel: _viewModel)),
    );
    if (created == true) {
      await _viewModel.load();
    }
  }

  Future<void> _openPontoForm() async {
    final grupo = _viewModel.grupoSelecionado;
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
      await _viewModel.load();
    }
  }

  Future<void> _openDetail(PontoConsumo ponto) async {
    final grupo = _viewModel.grupoSelecionado;
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
      await _viewModel.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasGroups = _viewModel.grupos.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leituras'),
        actions: [
          IconButton(
            tooltip: 'Criar grupo',
            onPressed: _openGrupoForm,
            icon: const Icon(Icons.create_new_folder_outlined),
          ),
        ],
      ),
      floatingActionButton: hasGroups
          ? FloatingActionButton.extended(
              onPressed: _openPontoForm,
              backgroundColor: AppColors.primaryAction,
              foregroundColor: AppColors.background,
              icon: const Icon(Icons.add),
              label: const Text('Medidor'),
            )
          : null,
      body: SafeArea(
        child: _viewModel.isLoading
            ? const Center(child: CircularProgressIndicator())
            : hasGroups
            ? _HomeContent(
                grupos: _viewModel.grupos,
                grupoSelecionado: _viewModel.grupoSelecionado,
                pontos: _viewModel.pontosFiltrados,
                totalPontos: _viewModel.pontos.length,
                searchController: _searchController,
                searchQuery: _viewModel.searchQuery,
                errorMessage: _viewModel.errorMessage,
                onGrupoChanged: (grupo) {
                  if (grupo != null) {
                    _viewModel.selectGrupo(grupo);
                  }
                },
                onSearchChanged: _viewModel.updateSearch,
                onCreateGrupo: _openGrupoForm,
                onCreatePonto: _openPontoForm,
                onOpenPonto: _openDetail,
              )
            : _EmptyGroups(onCreateGrupo: _openGrupoForm),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.grupos,
    required this.grupoSelecionado,
    required this.pontos,
    required this.totalPontos,
    required this.searchController,
    required this.searchQuery,
    required this.errorMessage,
    required this.onGrupoChanged,
    required this.onSearchChanged,
    required this.onCreateGrupo,
    required this.onCreatePonto,
    required this.onOpenPonto,
  });

  final List<Grupo> grupos;
  final Grupo? grupoSelecionado;
  final List<PontoConsumoResumo> pontos;
  final int totalPontos;
  final TextEditingController searchController;
  final String searchQuery;
  final String? errorMessage;
  final ValueChanged<Grupo?> onGrupoChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onCreateGrupo;
  final VoidCallback onCreatePonto;
  final ValueChanged<PontoConsumo> onOpenPonto;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        DropdownButtonFormField<Grupo>(
          value: grupoSelecionado,
          decoration: const InputDecoration(
            labelText: 'Grupo',
            prefixIcon: Icon(Icons.folder_outlined),
          ),
          items: grupos
              .map(
                (grupo) =>
                    DropdownMenuItem(value: grupo, child: Text(grupo.nome)),
              )
              .toList(),
          onChanged: onGrupoChanged,
        ),
        const SizedBox(height: 10),
        TextField(
          controller: searchController,
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            labelText: 'Buscar instalacao ou medidor',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: searchQuery.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Limpar busca',
                    onPressed: () => onSearchChanged(''),
                    icon: const Icon(Icons.close),
                  ),
          ),
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: 10),
          Text(
            errorMessage!,
            style: const TextStyle(
              color: AppColors.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                'Medidores',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.primaryText,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '${pontos.length}/$totalPontos',
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onCreateGrupo,
          icon: const Icon(Icons.create_new_folder_outlined, size: 18),
          label: const Text('Criar grupo'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryAction,
            side: const BorderSide(color: AppColors.primaryAction, width: 2),
            minimumSize: const Size.fromHeight(40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (pontos.isEmpty)
          _EmptyPontos(
            hasSearch: searchQuery.trim().isNotEmpty,
            onCreatePonto: onCreatePonto,
          )
        else
          ...pontos.map(
            (resumo) => _PontoCard(
              resumo: resumo,
              onTap: () => onOpenPonto(resumo.ponto),
            ),
          ),
      ],
    );
  }
}

class _PontoCard extends StatelessWidget {
  const _PontoCard({required this.resumo, required this.onTap});

  final PontoConsumoResumo resumo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ponto = resumo.ponto;
    final ultimaLeitura = resumo.ultimaLeitura;
    final instalacao = ponto.instalacao;
    final medidor = ponto.numeroMedidor;
    return Card(
      color: AppColors.background,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.primaryText, width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      instalacao != null
                          ? 'Instalacao: $instalacao'
                          : 'Medidor: ${medidor ?? '-'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.primaryText,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (instalacao != null && medidor != null)
                      Text(
                        'Medidor: $medidor',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                ultimaLeitura == null
                    ? 'Sem leitura'
                    : 'Leitura: ${ultimaLeitura.valorLeitura}',
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
          ),
        ),
      ),
    );
  }
}

class _EmptyGroups extends StatelessWidget {
  const _EmptyGroups({required this.onCreateGrupo});

  final VoidCallback onCreateGrupo;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.folder_open_outlined,
              size: 72,
              color: AppColors.primaryText,
            ),
            const SizedBox(height: 20),
            Text(
              'Crie um grupo para comecar',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            const Text(
              'As leituras ficam organizadas por blocos de trabalho.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.secondaryText, fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onCreateGrupo,
              icon: const Icon(Icons.add),
              label: const Text('Criar grupo'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPontos extends StatelessWidget {
  const _EmptyPontos({required this.hasSearch, required this.onCreatePonto});

  final bool hasSearch;
  final VoidCallback onCreatePonto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primaryText, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(hasSearch ? Icons.search_off : Icons.speed_outlined, size: 36),
          const SizedBox(height: 10),
          Text(
            hasSearch
                ? 'Nenhum medidor encontrado.'
                : 'Nenhum medidor neste grupo.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          if (!hasSearch) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onCreatePonto,
              icon: const Icon(Icons.add),
              label: const Text('Cadastrar medidor'),
            ),
          ],
        ],
      ),
    );
  }
}
