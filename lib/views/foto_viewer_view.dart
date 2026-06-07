import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/app_colors.dart';
import 'leitura_app_bar.dart';

/// Full-screen viewer for photos taken with the app camera.
///
/// Supports pinch-to-zoom via [InteractiveViewer] and sharing the
/// underlying file via the system share sheet.
class FotoViewerView extends StatelessWidget {
  const FotoViewerView({
    super.key,
    required this.fotoPath,
    this.descricao,
    this.shareText,
  });

  /// Absolute path to the image file in app-private storage.
  final String fotoPath;

  /// Optional description shown below the image.
  final String? descricao;

  /// Optional text sent alongside the photo when sharing.
  final String? shareText;

  Future<void> _share() async {
    await Share.shareXFiles(
      [XFile(fotoPath)],
      text: shareText,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: LeituraAppBar(
        title: 'Foto',
        actions: [
          IconButton(
            tooltip: 'Compartilhar',
            onPressed: _share,
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: Image.file(
                    File(fotoPath),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Text(
                        'Imagem indisponivel',
                        style: TextStyle(
                          color: AppColors.background,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (descricao != null && descricao!.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Colors.black,
                child: Text(
                  descricao!,
                  style: const TextStyle(
                    color: AppColors.background,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
