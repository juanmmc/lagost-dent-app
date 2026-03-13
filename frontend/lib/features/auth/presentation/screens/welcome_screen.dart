import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../widgets/lagos_logo.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Align(child: LagosLogo(size: 220)),
              const Spacer(),
              ElevatedButton(
                onPressed: () => context.push('/login/patient'),
                child: const Text('Ingresar como Paciente'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.push('/login/doctor'),
                child: const Text('Ingresar como Doctor'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
