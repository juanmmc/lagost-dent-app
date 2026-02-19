import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class LagosLogo extends StatelessWidget {
  const LagosLogo({super.key, this.size = 100});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.medical_services_rounded,
        color: AppColors.white,
        size: 44,
      ),
    );
  }
}
