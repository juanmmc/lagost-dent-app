import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../appointments/domain/models/appointment.dart';
import '../../../appointments/presentation/controllers/doctor_agenda_controller.dart';
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
    final state = ref.watch(doctorAgendaControllerProvider);

    ref.listen(doctorAgendaControllerProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.error!)));
      }
      if (next.success != null && next.success != previous?.success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.success!)));
      }
    });

    final pages = [
      _DoctorAgendaView(state: state),
      _DoctorSearchPatientView(state: state),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_index == 0 ? 'Inicio Doctor' : 'Buscar Paciente'),
        actions: [
          IconButton(
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).logout();
              if (!context.mounted) return;
              context.go('/');
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
  const _DoctorAgendaView({required this.state});

  final DoctorAgendaState state;

  @override
  Widget build(BuildContext context) {
    final controller = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(doctorAgendaControllerProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final now = DateTime.now();
                  final selected = await showDatePicker(
                    context: context,
                    initialDate: state.selectedDate ?? now,
                    firstDate: DateTime(now.year - 1),
                    lastDate: DateTime(now.year + 2),
                  );
                  if (selected != null) {
                    controller.setDate(selected);
                  }
                },
                icon: const Icon(Icons.event_rounded),
                label: Text(
                  state.selectedDate == null
                      ? 'Fecha'
                      : DateFormat('dd/MM/yyyy').format(state.selectedDate!),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String?>(
                initialValue: state.selectedStatus,
                decoration: const InputDecoration(labelText: 'Estado'),
                items: const [
                  DropdownMenuItem<String?>(value: null, child: Text('Todos')),
                  DropdownMenuItem<String?>(
                    value: 'pending',
                    child: Text('Pendiente'),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'completed',
                    child: Text('Atendida'),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'cancelled',
                    child: Text('Cancelada'),
                  ),
                ],
                onChanged: controller.setStatus,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (state.isLoading)
          const Center(child: CircularProgressIndicator())
        else if (state.agenda.isEmpty)
          const Card(
            child: ListTile(
              title: Text('No hay citas para los filtros actuales'),
              subtitle: Text('Prueba otra fecha o estado.'),
            ),
          )
        else
          ...state.agenda.map(
            (appointment) => _DoctorAppointmentCard(appointment: appointment),
          ),
      ],
    );
  }
}

class _DoctorAppointmentCard extends ConsumerWidget {
  const _DoctorAppointmentCard({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(doctorAgendaControllerProvider.notifier);
    final dateText = DateFormat('dd/MM/yyyy HH:mm').format(appointment.scheduledAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              appointment.patientName ?? 'Paciente #${appointment.patientId}',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text('$dateText · ${appointment.status}'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        appointment.isDone
                            ? null
                            : () => controller.updateStatus(
                              appointmentId: appointment.id,
                              status: 'completed',
                            ),
                    child: const Text('Marcar atendida'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        appointment.status.toLowerCase() == 'cancelled'
                            ? null
                            : () => controller.updateStatus(
                              appointmentId: appointment.id,
                              status: 'cancelled',
                            ),
                    child: const Text('Cancelar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DoctorSearchPatientView extends ConsumerWidget {
  const _DoctorSearchPatientView({required this.state});

  final DoctorAgendaState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(doctorAgendaControllerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: controller.setSearchQuery,
                  decoration: const InputDecoration(
                    labelText: 'Buscar por nombre',
                    prefixIcon: Icon(Icons.person_search_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: state.isActionLoading ? null : controller.searchPatients,
                child: const Text('Buscar'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (state.patients.isEmpty)
            const Card(
              child: ListTile(
                title: Text('Sin resultados por ahora'),
                subtitle: Text('Busca por nombre para ver pacientes.'),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: state.patients.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final patient = state.patients[index];
                  return Card(
                    child: ListTile(
                      title: Text(patient.name),
                      subtitle: Text(
                        patient.phone?.isNotEmpty == true
                            ? 'Tel: ${patient.phone}'
                            : 'ID: ${patient.id}',
                      ),
                      trailing: TextButton(
                        onPressed:
                            () => _showBookForPatientDialog(
                              context,
                              patientId: patient.id,
                              onConfirm:
                                  (scheduledAt) => controller.bookForPatient(
                                    patientId: patient.id,
                                    scheduledAt: scheduledAt,
                                  ),
                            ),
                        child: const Text('Agendar'),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

Future<void> _showBookForPatientDialog(
  BuildContext context, {
  required String patientId,
  required Future<void> Function(DateTime scheduledAt) onConfirm,
}) async {
  DateTime? date;
  TimeOfDay? time;

  await showDialog<void>(
    context: context,
    builder:
        (context) => StatefulBuilder(
          builder:
              (context, setState) => AlertDialog(
                title: const Text('Agendar para paciente'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Paciente: $patientId'),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final now = DateTime.now();
                        final selected = await showDatePicker(
                          context: context,
                          initialDate: now,
                          firstDate: now,
                          lastDate: DateTime(now.year + 2),
                        );
                        if (selected != null) {
                          setState(() => date = selected);
                        }
                      },
                      icon: const Icon(Icons.event),
                      label: Text(
                        date == null
                            ? 'Seleccionar fecha'
                            : DateFormat('dd/MM/yyyy').format(date!),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final selected = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (selected != null) {
                          setState(() => time = selected);
                        }
                      },
                      icon: const Icon(Icons.schedule),
                      label: Text(
                        time == null ? 'Seleccionar hora' : time!.format(context),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      if (date == null || time == null) return;

                      final scheduledAt = DateTime(
                        date!.year,
                        date!.month,
                        date!.day,
                        time!.hour,
                        time!.minute,
                      );

                      await onConfirm(scheduledAt);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    child: const Text('Confirmar'),
                  ),
                ],
              ),
        ),
  );
}
