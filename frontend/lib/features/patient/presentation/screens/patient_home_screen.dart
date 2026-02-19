import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';

class PatientHomeScreen extends ConsumerStatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  ConsumerState<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends ConsumerState<PatientHomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const _PatientAppointmentsView(),
      const _PatientBookingGuideView(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_index == 0 ? 'Inicio Paciente' : 'Agendar Cita'),
        actions: [
          IconButton(
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).logout();
              if (mounted) context.go('/');
            },
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            label: 'Agendar cita',
          ),
        ],
      ),
    );
  }
}

class _PatientAppointmentsView extends StatelessWidget {
  const _PatientAppointmentsView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        Card(
          child: ListTile(
            title: Text('Aún no hay citas cargadas'),
            subtitle: Text(
              'Aquí verás el listado y detalle con diagnóstico/receta',
            ),
          ),
        ),
      ],
    );
  }
}

class _PatientBookingGuideView extends StatelessWidget {
  const _PatientBookingGuideView();

  @override
  Widget build(BuildContext context) {
    const steps = [
      '1) Elegir titular o paciente asociado',
      '2) Seleccionar doctor activo',
      '3) Seleccionar fecha',
      '4) Seleccionar hora disponible',
      '5) Adjuntar comprobante de pago (QR)',
    ];

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) => Card(
        child: ListTile(
          leading: const Icon(Icons.check_circle_outline_rounded),
          title: Text(steps[index]),
        ),
      ),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemCount: steps.length,
    );
  }
}
