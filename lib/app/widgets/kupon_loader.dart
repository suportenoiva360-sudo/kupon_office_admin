import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Loader animado da KupOn — renderiza o logo animado
/// (`assets/icons/KUPON LOGO.json`, Lottie).
class KuponLoader extends StatelessWidget {
  final double size;

  const KuponLoader({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return Lottie.asset(
      'assets/icons/KUPON LOGO.json',
      width: size,
      height: size,
    );
  }
}
