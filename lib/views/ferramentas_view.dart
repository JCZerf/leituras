import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'leitura_app_bar.dart';

class FerramentasView extends StatelessWidget {
  const FerramentasView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const LeituraAppBar(title: 'Ferramentas'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            _ToolTile(
              icon: Icons.bolt_outlined,
              title: 'Estimador de consumo',
              subtitle: 'Calcule variacoes entre leituras.',
            ),
            SizedBox(height: 10),
            _ToolTile(
              icon: Icons.calculate_outlined,
              title: 'Calculadora',
              subtitle: 'Apoio rapido para conferencias em campo.',
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
    );
  }
}
