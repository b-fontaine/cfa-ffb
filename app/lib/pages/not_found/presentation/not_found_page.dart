import 'package:billard_cfa/shared/ui/missing_page_view.dart';
import 'package:flutter/material.dart';

/// Adresse inconnue ou mal formée : message localisé et retour à l'accueil.
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({required this.onHome, super.key});

  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) => MissingPageView(onHome: onHome);
}
