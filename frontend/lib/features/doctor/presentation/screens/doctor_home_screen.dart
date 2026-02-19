import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';

class DoctorHomeScreen extends ConsumerStatefulWidget {
  const DoctorHomeScreen({super.key});

  @override
  ConsumerState<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends ConsumerState<DoctorHomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [const _DoctorAgendaView(), const _DoctorSearchPatientView()];

    return Scaffold(
      appBar: AppBar(
        title: Text(_index == 0 ? 'Inicio Doctor' : 'Buscar Paciente'),
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
            icon: Icon(Icons.today_rounded),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_rounded),
            label: 'Buscar paciente',
          ),
        ],
      ),
    );
  }
}

class _DoctorAgendaView extends StatelessWidget {
  const _DoctorAgendaView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        Card(
          child: ListTile(
            title: Text('Agenda del día actual'),
            subtitle: Text(
              'Aquí se mostrará la agenda por fecha, estado y acciones de cita.',
            ),
          ),
        ),
      ],
    );
  }
}

class _DoctorSearchPatientView extends StatelessWidget {
  const _DoctorSearchPatientView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: const [
          TextField(
            decoration: InputDecoration(
              labelText: 'Buscar por nombre',
              prefixIcon: Icon(Icons.person_search_rounded),
            ),
          ),
          SizedBox(height: 12),
          Card(
            child: ListTile(
              title: Text('Sin resultados por ahora'),
              subtitle: Text(
                'Aquí podrás abrir datos, alergias, citas y agendar para el paciente.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
