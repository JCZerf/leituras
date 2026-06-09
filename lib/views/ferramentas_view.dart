import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../theme/app_colors.dart';
import '../repositories/app_database.dart';
import '../services/backup_service.dart';
import 'estimador_view.dart';
import 'leitura_app_bar.dart';

class FerramentasView extends StatefulWidget {
  const FerramentasView({super.key, required this.database});

  final AppDatabase database;

  @override
  State<FerramentasView> createState() => _FerramentasViewState();
}

class _FerramentasViewState extends State<FerramentasView> {
  late final BackupService _backupService;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _backupService = BackupService(appDatabase: widget.database);
  }

  Future<void> _handleExport() async {
    setState(() {
      _isLoading = true;
    });

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await _backupService.exportBackup();
      if (!mounted) return;
      scaffoldMessenger.clearSnackBars();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: AppColors.background),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Backup exportado com sucesso!',
                  style: TextStyle(
                    color: AppColors.background,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: AppColors.primaryText, width: 2),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.clearSnackBars();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Erro ao exportar backup: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleImport() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Atenção: Restaurar Backup',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: const Text(
            'Ao importar este backup, todos os dados atuais serão apagados e substituídos pelos dados do arquivo.\n\nEsta ação não pode ser desfeita. Deseja continuar?',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Cancelar',
                style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.secondaryText),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: AppColors.background,
              ),
              child: const Text(
                'Importar e Sobrescrever',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final file = result.files.single;
      String content;
      if (file.bytes != null) {
        content = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        content = await File(file.path!).readAsString();
      } else {
        throw Exception('Não foi possível ler o arquivo selecionado.');
      }

      await _backupService.importBackup(content);

      if (!mounted) return;
      scaffoldMessenger.clearSnackBars();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: AppColors.background),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Backup importado com sucesso! Os dados foram restaurados.',
                  style: TextStyle(
                    color: AppColors.background,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: AppColors.primaryText, width: 2),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.clearSnackBars();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Erro ao importar backup: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const LeituraAppBar(title: 'Ferramentas'),
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _ToolTile(
                  icon: Icons.bolt_outlined,
                  title: 'Estimador de consumo',
                  subtitle: 'Calcule variações entre leituras.',
                  onTap: _isLoading
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const EstimadorView()),
                          );
                        },
                ),
                const SizedBox(height: 12),
                _ToolTile(
                  icon: Icons.backup_outlined,
                  title: 'Exportar Backup',
                  subtitle: 'Salvar uma cópia de segurança de todos os seus dados.',
                  onTap: _isLoading ? null : _handleExport,
                ),
                const SizedBox(height: 12),
                _ToolTile(
                  icon: Icons.restore_outlined,
                  title: 'Importar Backup',
                  subtitle: 'Restaurar seus dados a partir de uma cópia salva.',
                  onTap: _isLoading ? null : _handleImport,
                ),
              ],
            ),
            if (_isLoading)
              const Positioned.fill(
                child: ColoredBox(
                  color: Colors.black26,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryAction,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primaryText, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.primaryText,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
