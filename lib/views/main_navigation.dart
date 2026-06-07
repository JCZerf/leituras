import 'package:flutter/material.dart';

import '../repositories/grupo_repository.dart';
import '../repositories/historico_leitura_repository.dart';
import '../repositories/ponto_consumo_repository.dart';
import '../theme/app_colors.dart';
import '../viewmodels/app_state.dart';
import 'ferramentas_view.dart';
import 'grupos_view.dart';
import 'leituras_view.dart';
import 'preventivo_internos_view.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({
    super.key,
    required this.grupoRepository,
    required this.pontoConsumoRepository,
    required this.historicoLeituraRepository,
  });

  final GrupoRepository grupoRepository;
  final PontoConsumoRepository pontoConsumoRepository;
  final HistoricoLeituraRepository historicoLeituraRepository;

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  late final AppState _appState;

  @override
  void initState() {
    super.initState();
    _appState = AppState()..addListener(_handleAppStateChanged);
  }

  @override
  void dispose() {
    _appState
      ..removeListener(_handleAppStateChanged)
      ..dispose();
    super.dispose();
  }

  void _handleAppStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HeroControllerScope.none(
        child: IndexedStack(
          index: _appState.currentTabIndex,
          children: [
            GruposView(
              appState: _appState,
              grupoRepository: widget.grupoRepository,
              pontoConsumoRepository: widget.pontoConsumoRepository,
            ),
            LeiturasView(
              appState: _appState,
              grupoRepository: widget.grupoRepository,
              pontoConsumoRepository: widget.pontoConsumoRepository,
              historicoLeituraRepository: widget.historicoLeituraRepository,
            ),
            PreventivoInternosView(
              appState: _appState,
              grupoRepository: widget.grupoRepository,
              pontoConsumoRepository: widget.pontoConsumoRepository,
              historicoLeituraRepository: widget.historicoLeituraRepository,
            ),
            const FerramentasView(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _appState.currentTabIndex,
        onDestinationSelected: _appState.selectTab,
        backgroundColor: AppColors.background,
        indicatorColor: const Color(0x1F0056B3),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: 'Grupos',
          ),
          NavigationDestination(
            icon: Icon(Icons.speed_outlined),
            selectedIcon: Icon(Icons.speed),
            label: 'Leituras',
          ),
          NavigationDestination(
            icon: Icon(Icons.lock_outline),
            selectedIcon: Icon(Icons.lock),
            label: 'Preventivo',
          ),
          NavigationDestination(
            icon: Icon(Icons.build_outlined),
            selectedIcon: Icon(Icons.build),
            label: 'Ferramentas',
          ),
        ],
      ),
    );
  }
}
