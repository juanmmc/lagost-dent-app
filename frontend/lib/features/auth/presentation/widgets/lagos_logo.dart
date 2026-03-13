import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class LagosLogo extends StatelessWidget {
  const LagosLogo({super.key, this.size = 100});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/images/logo.webp',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) {
          return Container(
            color: AppColors.primary,
            child: const Icon(
              Icons.medical_services_rounded,
              color: AppColors.white,
              size: 44,
            ),
          );
        },
      ),
    );
  }
}
