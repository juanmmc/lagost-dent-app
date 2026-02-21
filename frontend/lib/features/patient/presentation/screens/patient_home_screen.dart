import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../appointments/domain/models/appointment.dart';
import '../../../appointments/presentation/controllers/patient_appointments_controller.dart';
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
    final state = ref.watch(patientAppointmentsControllerProvider);

    ref.listen(patientAppointmentsControllerProvider, (previous, next) {
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
      _PatientAppointmentsView(
        appointments: state.appointments,
        isLoading: state.isLoading,
        onRefresh:
            () =>
                ref
                    .read(patientAppointmentsControllerProvider.notifier)
                    .loadInitialData(),
      ),
      _PatientBookingFlowView(state: state),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_index == 0 ? 'Inicio Paciente' : 'Agendar Cita'),
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
  const _PatientAppointmentsView({
    required this.appointments,
    required this.isLoading,
    required this.onRefresh,
  });

  final List<Appointment> appointments;
  final bool isLoading;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (appointments.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: const [
            Card(
              child: ListTile(
                title: Text('Aún no tienes citas registradas'),
                subtitle: Text('Agenda una cita desde la pestaña Agendar cita.'),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: appointments.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final appointment = appointments[index];
          final dateText = DateFormat(
            'dd/MM/yyyy HH:mm',
          ).format(appointment.scheduledAt);

          return Card(
            child: ListTile(
              title: Text(appointment.doctorName ?? 'Doctor #${appointment.doctorId}'),
              subtitle: Text('$dateText · Estado: ${appointment.status}'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _showAppointmentDetail(context, appointment),
            ),
          );
        },
      ),
    );
  }
}

class _PatientBookingFlowView extends ConsumerWidget {
  const _PatientBookingFlowView({required this.state});

  final PatientAppointmentsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(patientAppointmentsControllerProvider.notifier);
    final selectedDoctor =
        state.doctors.where((doctor) => doctor.id == state.selectedDoctorId).isEmpty
            ? null
            : state.doctors
                .where((doctor) => doctor.id == state.selectedDoctorId)
                .first;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _StepHeader(number: 1, text: 'Elegir titular o paciente asociado'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment<bool>(value: false, label: Text('Titular')),
                    ButtonSegment<bool>(value: true, label: Text('Asociado')),
                  ],
                  selected: {state.forAssociatedPatient},
                  onSelectionChanged:
                      (selection) =>
                          controller.setForAssociatedPatient(selection.first),
                ),
                if (state.forAssociatedPatient) ...[
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: controller.setAssociatedPatientId,
                    decoration: const InputDecoration(
                      labelText: 'ID del paciente asociado',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const _StepHeader(number: 2, text: 'Seleccionar doctor activo'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: DropdownButtonFormField<String>(
              initialValue: state.selectedDoctorId,
              decoration: const InputDecoration(labelText: 'Doctor'),
              items:
                  state.doctors
                      .map(
                        (doctor) => DropdownMenuItem<String>(
                          value: doctor.id,
                          child: Text(doctor.label),
                        ),
                      )
                      .toList(),
              onChanged: controller.setDoctor,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const _StepHeader(number: 3, text: 'Seleccionar fecha'),
        Card(
          child: ListTile(
            leading: const Icon(Icons.event_outlined),
            title: Text(
              state.selectedDate == null
                  ? 'Elegir fecha'
                  : DateFormat('dd/MM/yyyy').format(state.selectedDate!),
            ),
            onTap: () async {
              final now = DateTime.now();
              final date = await showDatePicker(
                context: context,
                firstDate: now,
                lastDate: DateTime(now.year + 2),
                initialDate: state.selectedDate ?? now,
              );
              if (date != null) controller.setDate(date);
            },
          ),
        ),
        const SizedBox(height: 12),
        const _StepHeader(number: 4, text: 'Seleccionar hora disponible'),
        Card(
          child: ListTile(
            leading: const Icon(Icons.schedule_rounded),
            title: Text(
              state.selectedTime == null
                  ? 'Elegir hora'
                  : state.selectedTime!.format(context),
            ),
            onTap: () async {
              final time = await showTimePicker(
                context: context,
                initialTime: state.selectedTime ?? TimeOfDay.now(),
              );
              if (time != null) controller.setTime(time);
            },
          ),
        ),
        const SizedBox(height: 12),
        const _StepHeader(number: 5, text: 'Adjuntar comprobante de pago (QR)'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: controller.setPaymentReference,
              decoration: const InputDecoration(
                labelText: 'Referencia/ID del comprobante QR',
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed:
              state.isSubmitting
                  ? null
                  : () => controller.bookAppointment(),
          icon:
              state.isSubmitting
                  ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Icon(Icons.check_rounded),
          label: Text(
            state.isSubmitting
                ? 'Agendando...'
                : 'Confirmar cita${selectedDoctor != null ? ' con ${selectedDoctor.name}' : ''}',
          ),
        ),
      ],
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        '$number) $text',
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

void _showAppointmentDetail(BuildContext context, Appointment appointment) {
  final dateText = DateFormat('dd/MM/yyyy HH:mm').format(appointment.scheduledAt);

  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder:
        (context) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                appointment.doctorName ?? 'Doctor #${appointment.doctorId}',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text('Fecha: $dateText'),
              Text('Estado: ${appointment.status}'),
              const SizedBox(height: 8),
              Text(
                'Diagnóstico: ${appointment.diagnosis?.trim().isNotEmpty == true ? appointment.diagnosis : 'Pendiente'}',
              ),
              const SizedBox(height: 4),
              Text(
                'Receta: ${appointment.prescription?.trim().isNotEmpty == true ? appointment.prescription : 'Pendiente'}',
              ),
            ],
          ),
        ),
  );
}
