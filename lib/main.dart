import 'package:flutter/material.dart';

import 'repositories/app_database.dart';
import 'repositories/grupo_repository.dart';
import 'repositories/historico_leitura_repository.dart';
import 'repositories/ponto_consumo_repository.dart';
import 'theme/app_colors.dart';
import 'views/main_navigation.dart';

import 'views/splash_view.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _initialized = false;
  late final AppDatabase _database;
  late final GrupoRepository _grupoRepository;
  late final PontoConsumoRepository _pontoConsumoRepository;
  late final HistoricoLeituraRepository _historicoLeituraRepository;

  @override
  void initState() {
    super.initState();
    _database = AppDatabase();
    _grupoRepository = GrupoRepository(_database);
    _pontoConsumoRepository = PontoConsumoRepository(_database);
    _historicoLeituraRepository = HistoricoLeituraRepository(_database);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Leituras',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryAction,
          brightness: Brightness.light,
          primary: AppColors.primaryAction,
          error: AppColors.error,
          surface: AppColors.background,
          onPrimary: AppColors.background,
          onSurface: AppColors.primaryText,
          onError: AppColors.background,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.appBarBackground,
          foregroundColor: AppColors.appBarForeground,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: AppColors.appBarForeground,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.primaryText),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
              color: AppColors.primaryAction,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.error, width: 2),
          ),
        ),
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: AppColors.primaryText,
          displayColor: AppColors.primaryText,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryAction,
            foregroundColor: AppColors.background,
            minimumSize: const Size(48, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        useMaterial3: true,
      ),
      home: _initialized
          ? MainNavigation(
              database: _database,
              grupoRepository: _grupoRepository,
              pontoConsumoRepository: _pontoConsumoRepository,
              historicoLeituraRepository: _historicoLeituraRepository,
            )
          : SplashView(
              onInitializationComplete: () {
                setState(() {
                  _initialized = true;
                });
              },
            ),
    );
  }
}
