import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Reusable AppBar with the Leituras identity.
///
/// Uses the primary-action blue (#0056B3) background and white foreground for
/// maximum outdoor contrast. The [toolbarHeight] is slightly taller than the
/// Material default so the title has breathing room in field conditions.
///
/// ```dart
/// Scaffold(
///   appBar: LeituraAppBar(title: 'Leituras: Bloco A'),
///   body: …,
/// )
/// ```
class LeituraAppBar extends StatelessWidget implements PreferredSizeWidget {
  const LeituraAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
  });

  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;

  static const double _toolbarHeight = 64;

  @override
  Size get preferredSize => const Size.fromHeight(_toolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: _toolbarHeight,
      backgroundColor: AppColors.primaryAction,
      foregroundColor: AppColors.background,
      elevation: 2,
      shadowColor: Colors.black54,
      centerTitle: false,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.background,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.background),
      actionsIconTheme: const IconThemeData(color: AppColors.background),
      actions: actions,
    );
  }
}
