import 'package:billard_cfa/shared/ui/page_header.dart';
import 'package:billard_cfa/shared/ui/responsive_body.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Page défilante standard : en-tête, contenu centré et limité en largeur
/// (confortable du smartphone au desktop). [onBack] ajoute un retour de 48 dp.
class ScrollPage extends StatelessWidget {
  const ScrollPage({
    required this.title,
    required this.children,
    this.subtitle,
    this.onBack,
    this.backLabel,
    super.key,
  }) : assert(
         onBack == null || backLabel != null,
         'backLabel is required with onBack',
       );

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final VoidCallback? onBack;

  /// Libellé du retour (obligatoire avec [onBack]).
  final String? backLabel;

  @override
  Widget build(BuildContext context) {
    final onBack = this.onBack;
    return Scaffold(
      body: SafeArea(
        child: ResponsiveBody(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (onBack != null)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back),
                      label: Text(backLabel!),
                    ),
                  ),
                PageHeader(title: title, subtitle: subtitle),
                const SizedBox(height: AppSpacing.md),
                for (final child in children) ...[
                  child,
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
