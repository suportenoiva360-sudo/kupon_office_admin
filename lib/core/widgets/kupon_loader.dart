import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class KuponLoader extends StatelessWidget {
  const KuponLoader({super.key, this.size = 140});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Lottie.asset(
        'assets/icons/kupon_logo.json',
        width: size,
        height: size,
        fit: BoxFit.contain,
        animate: true,
      ),
    );
  }
}