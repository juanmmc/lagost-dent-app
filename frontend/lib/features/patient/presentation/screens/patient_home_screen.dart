import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_config.dart';
import '../../../appointments/data/appointments_repository.dart';
import '../../../appointments/domain/models/appointment.dart';
import '../../../appointments/presentation/controllers/patient_appointments_controller.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

class PatientHomeScreen extends ConsumerStatefulWidget {
  const PatientHomeScreen({super.key, this.initialAppointmentId});

  final String? initialAppointmentId;

  @override
  ConsumerState<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends ConsumerState<PatientHomeScreen> {
  static const String _bookingSuccessMessage = 'Cita agendada correctamente';
  int _index = 0;
  bool _didHandleInitialAppointment = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_openInitialAppointmentIfNeeded);
  }

  Future<void> _openInitialAppointmentIfNeeded() async {
    final appointmentId = widget.initialAppointmentId;
    if (_didHandleInitialAppointment || appointmentId == null || appointmentId.isEmpty) {
      return;
    }
    _didHandleInitialAppointment = true;

    try {
      final repository = ref.read(appointmentsRepositoryProvider);
      final detailed = await repository.fetchAppointmentDetail(
        appointmentId: appointmentId,
      );
      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _PatientAppointmentDetailScreen(appointment: detailed),
        ),
      );

      if (!mounted) return;
      await ref
          .read(patientAppointmentsControllerProvider.notifier)
          .loadInitialData();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir el detalle de la cita: $error')),
      );
    }
  }

  Future<void> _onDestinationSelected(int value) async {
    setState(() => _index = value);
    if (value == 0) {
      await ref
          .read(patientAppointmentsControllerProvider.notifier)
          .loadInitialData();
    }
  }

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
        if (next.success == _bookingSuccessMessage && _index != 0) {
          setState(() => _index = 0);
        }
      }
    });

    final pages = [
      _PatientAppointmentsView(
        appointments: state.appointments,
        isLoading: state.isLoading,
        onRefresh: () => ref
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
        onDestinationSelected: _onDestinationSelected,
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
                subtitle: Text(
                  'Agenda una cita desde la pestaña Agendar cita.',
                ),
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
              title: Text(
                appointment.doctorName ?? 'Doctor #${appointment.doctorId}',
              ),
              subtitle: Text(
                'Paciente: ${appointment.patientName ?? 'Paciente #${appointment.patientId}'}\n'
                '$dateText · Estado: ${appointment.statusDescriptor}',
              ),
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
    final isFormProcessing =
      state.isSubmitting ||
      state.isLoadingAvailability ||
      state.isUploadingReceipt;
    final selectedDoctor =
        state.doctors
            .where((doctor) => doctor.id == state.selectedDoctorId)
            .isEmpty
        ? null
        : state.doctors
              .where((doctor) => doctor.id == state.selectedDoctorId)
              .first;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _StepHeader(
          number: 1,
          text: 'Elegir titular o paciente asociado',
        ),
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
                  onSelectionChanged: (selection) =>
                      controller.setForAssociatedPatient(selection.first),
                ),
                if (state.forAssociatedPatient) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: state.isCreatingAssociate
                          ? null
                          : () async {
                              final associate =
                                  await _askNewAssociatedPatientData(context);
                              if (!context.mounted || associate == null) {
                                return;
                              }

                              await controller.createAssociatedPatient(
                                name: associate.$1,
                                phone: associate.$2,
                                birthdate: associate.$3,
                              );
                            },
                      icon: state.isCreatingAssociate
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.person_add_alt_1_rounded),
                      label: Text(
                        state.isCreatingAssociate
                            ? 'Agregando...'
                            : 'Agregar asociado',
                      ),
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue:
                        state.associatedPatients
                            .where(
                              (patient) =>
                                  patient.id == state.associatedPatientId,
                            )
                            .isEmpty
                        ? null
                        : state.associatedPatientId,
                    decoration: InputDecoration(
                      labelText: 'Paciente asociado',
                      helperText: state.associatedPatients.isEmpty
                        ? 'No hay asociados. Usa "Agregar asociado" para registrar uno.'
                          : null,
                    ),
                    items: state.associatedPatients
                        .map(
                          (patient) => DropdownMenuItem<String>(
                            value: patient.id,
                            child: Text(
                              patient.phone == null || patient.phone!.isEmpty
                                  ? patient.name
                                  : '${patient.name} · ${patient.phone}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: state.associatedPatients.isEmpty
                        ? null
                        : (value) =>
                              controller.setAssociatedPatientId(value ?? ''),
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
              items: state.doctors
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
              if (date != null) {
                await controller.setDate(date);
              }
            },
          ),
        ),
        const SizedBox(height: 12),
        const _StepHeader(number: 4, text: 'Seleccionar hora disponible'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Builder(
              builder: (context) {
                if (state.selectedDate == null) {
                  return const ListTile(
                    leading: Icon(Icons.schedule_rounded),
                    title: Text('Primero selecciona una fecha'),
                  );
                }

                if (state.isLoadingAvailability) {
                  return const ListTile(
                    leading: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    title: Text('Consultando horas disponibles...'),
                  );
                }

                if (state.availableSlots.isEmpty) {
                  return const ListTile(
                    leading: Icon(Icons.event_busy_outlined),
                    title: Text('No hay horas disponibles en esta fecha'),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.selectedTime == null
                          ? 'Selecciona una hora'
                          : 'Hora seleccionada: ${state.selectedTime!.format(context)}',
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: state.availableSlots.map((slot) {
                        final selected = state.selectedTime == slot;
                        return ChoiceChip(
                          label: Text(slot.format(context)),
                          selected: selected,
                          onSelected: (_) => controller.setTime(slot),
                        );
                      }).toList(),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        const _StepHeader(number: 5, text: 'Adjuntar comprobante de pago (QR)'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _PaymentQrPreview(),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: state.isUploadingReceipt
                      ? null
                      : () async {
                          FilePickerResult? picked;
                          try {
                            picked = await FilePicker.platform.pickFiles(
                              withData: true,
                              type: FileType.any,
                            );
                          } on MissingPluginException {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Selector de archivos no disponible. Reinicia la app por completo e intenta nuevamente.',
                                ),
                              ),
                            );
                            return;
                          }

                          if (picked == null || picked.files.isEmpty) return;
                          await controller.uploadPaymentReceipt(
                            picked.files.first,
                          );
                        },
                  icon: state.isUploadingReceipt
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.attach_file_rounded),
                  label: Text(
                    state.isUploadingReceipt
                        ? 'Subiendo comprobante...'
                        : 'Seleccionar comprobante',
                  ),
                ),
                if (state.paymentReceiptAttachmentId != null) ...[
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.insert_drive_file_outlined),
                    title: Text(
                      state.paymentReceiptFileName ?? 'Comprobante adjunto',
                    ),
                    subtitle: Text(
                      'Adjunto ID: ${state.paymentReceiptAttachmentId}',
                    ),
                    trailing: IconButton(
                      tooltip: 'Quitar comprobante',
                      onPressed: controller.clearPaymentReceipt,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  const Text('No has adjuntado un comprobante todavía.'),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: isFormProcessing
              ? null
              : () => controller.bookAppointment(),
          icon: isFormProcessing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_rounded),
          label: Text(
            isFormProcessing
                ? 'Procesando...'
                : 'Confirmar cita${selectedDoctor != null ? ' con ${selectedDoctor.name}' : ''}',
          ),
        ),
      ],
    );
  }
}

Future<(String, String, String)?> _askNewAssociatedPatientData(
  BuildContext context,
) async {
  return showDialog<(String, String, String)>(
    context: context,
    builder: (_) => const _NewAssociatedPatientDialog(),
  );
}

class _NewAssociatedPatientDialog extends StatefulWidget {
  const _NewAssociatedPatientDialog();

  @override
  State<_NewAssociatedPatientDialog> createState() =>
      _NewAssociatedPatientDialogState();
}

class _NewAssociatedPatientDialogState extends State<_NewAssociatedPatientDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _birthdate;
  String? _validationMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthdate() async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      initialDate: DateTime(2000),
    );
    if (!mounted || selected == null) return;

    final formatted =
        '${selected.year.toString().padLeft(4, '0')}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}';
    setState(() {
      _birthdate = formatted;
      _validationMessage = null;
    });
  }

  void _submit() {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    final date = _birthdate?.trim() ?? '';
    if (date.isEmpty) {
      setState(() {
        _validationMessage =
            'Selecciona la fecha de nacimiento del asociado';
      });
      return;
    }

    Navigator.of(context).pop((
      _nameController.text.trim(),
      _phoneController.text.trim(),
      date,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Agregar paciente asociado'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Nombre completo'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Ingresa el nombre'
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Telefono'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Ingresa el telefono'
                    : null,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickBirthdate,
                icon: const Icon(Icons.calendar_today_rounded),
                label: Text(
                  _birthdate == null
                      ? 'Seleccionar fecha de nacimiento'
                      : 'Nacimiento: $_birthdate',
                ),
              ),
              if (_validationMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _validationMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Guardar asociado'),
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
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _PatientAppointmentDetailScreen(appointment: appointment),
    ),
  );
}

class _PatientAppointmentDetailScreen extends ConsumerStatefulWidget {
  const _PatientAppointmentDetailScreen({required this.appointment});

  final Appointment appointment;

  @override
  ConsumerState<_PatientAppointmentDetailScreen> createState() =>
      _PatientAppointmentDetailScreenState();
}

class _PatientAppointmentDetailScreenState
    extends ConsumerState<_PatientAppointmentDetailScreen> {
  bool _isLoadingDetail = false;
  Appointment? _detailedAppointment;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadAppointmentDetail);
  }

  @override
  Widget build(BuildContext context) {
    final appointment = _detailedAppointment ?? widget.appointment;
    final authToken = ref.watch(
      authControllerProvider.select((state) => state.session?.token),
    );
    final dateText = DateFormat(
      'dd/MM/yyyy HH:mm',
    ).format(appointment.scheduledAt);
    final patientText =
        appointment.patientName ?? 'Paciente #${appointment.patientId}';
    final doctorText =
        appointment.doctorName ?? 'Doctor #${appointment.doctorId}';
    final receiptUrl = appointment.depositSlipAttachmentUrl?.trim();
    final receiptPath = appointment.depositSlipAttachmentPath?.trim();
    final receiptMime = appointment.depositSlipAttachmentMime?.trim();
    final receiptSource =
      receiptUrl != null && receiptUrl.isNotEmpty ? receiptUrl : receiptPath;
    final receiptUri = _resolveAttachmentUri(receiptSource);
    final canPreviewReceipt =
      receiptUri != null && _isImageAttachment(receiptSource, receiptMime);
    final recipeUrl = appointment.recipeAttachmentUrl?.trim();
    final recipePath = appointment.recipeAttachmentPath?.trim();
    final recipeMime = appointment.recipeAttachmentMime?.trim();
    final recipeSource =
      recipeUrl != null && recipeUrl.isNotEmpty ? recipeUrl : recipePath;
    final recipeUri = _resolveAttachmentUri(recipeSource);
    final canPreviewRecipe =
      recipeUri != null && _isImageAttachment(recipeSource, recipeMime);
    final imageHeaders = authToken == null || authToken.isEmpty
        ? null
        : <String, String>{'Authorization': 'Bearer $authToken'};
    final diagnosisText = appointment.diagnosis?.trim().isNotEmpty == true
        ? appointment.diagnosis!.trim()
        : 'Pendiente';

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de cita')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_isLoadingDetail)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doctorText,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(
                    icon: Icons.event_outlined,
                    label: 'Fecha y hora',
                    value: dateText,
                  ),
                  const SizedBox(height: 10),
                  _DetailRow(
                    icon: Icons.person_outline,
                    label: 'Paciente',
                    value: patientText,
                  ),
                  const SizedBox(height: 10),
                  _DetailRow(
                    icon: Icons.info_outline,
                    label: 'Estado',
                    value: appointment.statusDescriptor,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Comprobante de pago',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    appointment.depositSlipAttachmentId?.isNotEmpty == true
                        ? 'Comprobante adjunto'
                        : 'No hay comprobante adjunto en esta cita.',
                  ),
                  if (canPreviewReceipt) ...[
                    const SizedBox(height: 12),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _showReceiptPreview(
                        context: context,
                        imageUrl: receiptUri.toString(),
                        headers: imageHeaders,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AspectRatio(
                          aspectRatio: 16 / 10,
                          child: Image.network(
                            receiptUri.toString(),
                            headers: imageHeaders,
                            fit: BoxFit.cover,
                            loadingBuilder:
                                (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                },
                            errorBuilder: (_, _, _) {
                              return Container(
                                color: Theme.of(context).colorScheme.surface,
                                alignment: Alignment.center,
                                child: const Text(
                                  'No se pudo cargar la imagen del comprobante',
                                  textAlign: TextAlign.center,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Toca la imagen para verla en grande y hacer zoom',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ] else if (
                    receiptSource != null && receiptSource.isNotEmpty
                  ) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'El comprobante adjunto no es una imagen previsualizable.',
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Diagnóstico',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(diagnosisText),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Receta',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    appointment.recipeAttachmentId?.isNotEmpty == true
                        ? 'Receta adjunta' : 'Pendiente',
                  ),
                  if (canPreviewRecipe) ...[
                    const SizedBox(height: 12),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _showReceiptPreview(
                        context: context,
                        imageUrl: recipeUri.toString(),
                        headers: imageHeaders,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AspectRatio(
                          aspectRatio: 16 / 10,
                          child: Image.network(
                            recipeUri.toString(),
                            headers: imageHeaders,
                            fit: BoxFit.cover,
                            loadingBuilder:
                                (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                },
                            errorBuilder: (_, _, _) {
                              return Container(
                                color: Theme.of(context).colorScheme.surface,
                                alignment: Alignment.center,
                                child: const Text(
                                  'No se pudo cargar la imagen de la receta',
                                  textAlign: TextAlign.center,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Toca la imagen para verla en grande y hacer zoom',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ] else if (recipeSource != null && recipeSource.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'El adjunto de receta no es una imagen previsualizable.',
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadAppointmentDetail() async {
    setState(() => _isLoadingDetail = true);
    try {
      final repository = ref.read(appointmentsRepositoryProvider);
      final detailed = await repository.fetchAppointmentDetail(
        appointmentId: widget.appointment.id,
      );
      if (!mounted) return;
      setState(() => _detailedAppointment = detailed);
    } catch (_) {
      // Keep fallback data from appointments list when detail fetch fails.
    } finally {
      if (mounted) setState(() => _isLoadingDetail = false);
    }
  }

  Uri? _resolveAttachmentUri(String? rawPath) {
    if (rawPath == null || rawPath.isEmpty) return null;

    final parsed = Uri.tryParse(rawPath);
    if (parsed != null && parsed.hasScheme) {
      final rewritten = _rewriteLocalhostUriIfNeeded(parsed);
      return rewritten;
    }

    final base = Uri.tryParse(AppConfig.apiBaseUrl);
    if (base == null) {
      return null;
    }

    final normalizedPath = _normalizeAttachmentPath(rawPath);
    return base.resolveUri(Uri.parse(normalizedPath));
  }

  Uri _rewriteLocalhostUriIfNeeded(Uri uri) {
    final host = uri.host.toLowerCase();
    if (host != 'localhost' && host != '127.0.0.1') {
      return uri;
    }

    final base = Uri.tryParse(AppConfig.apiBaseUrl);
    if (base == null || base.host.isEmpty) return uri;

    return uri.replace(
      scheme: base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : uri.port,
    );
  }

  String _normalizeAttachmentPath(String rawPath) {
    final trimmed = rawPath.trim();
    final withoutLeadingSlash = trimmed.startsWith('/')
        ? trimmed.substring(1)
        : trimmed;

    if (withoutLeadingSlash.startsWith('storage/')) {
      return '/$withoutLeadingSlash';
    }

    if (withoutLeadingSlash.startsWith('attachments/')) {
      return '/storage/$withoutLeadingSlash';
    }

    return trimmed.startsWith('/') ? trimmed : '/$trimmed';
  }

  bool _isImageAttachment(String? path, String? mime) {
    final normalizedMime = mime?.toLowerCase().trim();
    if (normalizedMime != null && normalizedMime.isNotEmpty) {
      return normalizedMime.startsWith('image/');
    }

    if (path == null || path.isEmpty) return false;
    final normalizedPath = path.toLowerCase();
    return normalizedPath.endsWith('.png') ||
        normalizedPath.endsWith('.jpg') ||
        normalizedPath.endsWith('.jpeg') ||
        normalizedPath.endsWith('.webp') ||
        normalizedPath.endsWith('.gif');
  }

  Future<void> _showReceiptPreview({
    required BuildContext context,
    required String imageUrl,
    Map<String, String>? headers,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('Comprobante'),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 5,
              child: Image.network(
                imageUrl,
                headers: headers,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No se pudo abrir la imagen del comprobante',
                      style: TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 2),
              Text(value),
            ],
          ),
        ),
      ],
    );
  }
}

class _PaymentQrPreview extends StatelessWidget {
  const _PaymentQrPreview();

  // Reemplazar por el base64 real del QR de pago.
  static const String _hardcodedPaymentQrBase64 =
      'data:image/jpeg;base64,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AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA//xAAC/9oADAMBAAIAAwAAACH77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777D/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8AvPPLLLDDDDDDDDDzzzzzzzzzzzzzjDDPPHHHX7777775lDT333333uMMMAARzzz7uMMEEE3z777IAAAU33//APywAAAAOe+kZ2NCU+++++sGMdy753YJoLL35ka+6zDDBBFc8++yiAAAN9//AP8A7CAAAAI77/33JSrHPH77776t3336Y7IIFoBB4pxUEMEEEVz777IAAAE13/8A/wDoAAAABnv/AP3nEEFE4sID77776/33830DJuv3OJvMnygEE1z777KAAA01/wD/AP8AAAAAAA57/wD9xBBBDO+o8AZe++++/wA40wogDT/iU9gwY4xTPPvsggAABXf/AP8A6wgAAAGO/wD/AH3EEEEI57WKFleX777778IIARzzz7qMMEEEXz777IAAAA33/wD++gAAAAGe/wD/AHmEEEIY77qJQwvZQn777774AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD777774AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD777774AAAAAAAAAQwwQAAgAAAAwAAAwAwAAQQgwwAwQQwAwwQAwwgAAAAAAAAD777774AAAAAAAADzjCxCQACCyiAABwiwQDiRAhDwxDSzDiAhxDzwAAAAAAAAAD777774AAAAAAAADygAySQwwRAByxCwzBRDRzggRDwCRwRTiSggiQAAAAAAAAAD777774AAAAAAAADQQChzTBwywjwDCygTxBCwDTiDjjATiADDwSBQgAAAAAAAAD777774AAAAAAAAAwzSSiQCDRyCTDTARBSSAgQDwziTyyAhCQwCQCAAAAAAAAAD777774AAAAAAAADAjCBSgjSSQSRhCSxDSRAgAwADAhBBjSwRhzBSgAAAAAAAAD777774AAAAAAAAChRTDiRTDTQxQCgixTAgTCjSBAgQhiDBDAgAwwAAAAAAAAAD777774AAAAAAAABwBShQSQggAzDjjwjgTBCBSRDBCSDTBiSgCTxAgAAAAAAAAD777774AAAAAAAAARRiDCTByDQgADTDyxSShjjiBCiwjzCSzwxwQCgAAAAAAAAD777774AAAAAAAAAQDSSzzyAAShDTyyBRSgzgRxDTyBCjgBwiiRygAAAAAAAAAD777774AAAAAAAAADCiiyyhASywzDRjDxhBTyDDRihTRxSgAQjCwAAAAAAAAAAD777774AAAAAAAAAwCzBChAwQDCjzgABzzxSwTDBhQwBDxSCiyRyQAAAAAAAAAD777774AAAAAAAACxADyAAwSwyQBQAxwjChzQjShijASThDDRDDQSAAAAAAAAAD777774AAAAAAAABAiRBBxjRiBAxAgCAiDThhggywRAARjwSzjRwAAAAAAAAAAD777774AAAAAAAACyTxAThwxBSQARSBDRzDDhRTyxAyQjyQwDRQQQAAAAAAAAAD777774AAAAAAAABhCSSjwgjgAwwgjSBjwBhCyhRwiDSzBhwgRDTyAAAAAAAAAD777774AAAAAAAAADSQgxBiSQyQSQSBjiBAgABCgBDRAiQQBQSxwggAAAAAAAAD777774AAAAAAAAAQDwjAixRQgTyxyAQBiGkhAggRxBBgygDwSzjCAAAAAAAAAD777774AAAAAAAABjBxySCSAQgAzxBiACAiiAASxCiDygiDAzSCgAAAAAAAAAAD777774AAAAAAAAChxQDwSgCxQATAiwAABDwgAQyRATgxyBTjACgAAAAAAAAAAD777774AAAAAAAADRDShTRTRxgAwCQAAABRiAAABTCzhDCRBTiDxwgAAAAAAAAD777774AAAAAAAABRwAgzDgBRSSCiRwQhRTxADSzBhCQDADAzDSgCAAAAAAAAAD777774AAAAAAAACRRSQjjxxjRwghSjwQjAAAzzSyQyQQjQyyQAQgAAAAAAAAAD777774AAAAAAAAADywyCSyQhTzzBhTTTADyCTAxAgDyhAyAyiDhCAAAAAAAAAD777774AAAAAAAAAChwQgRCzAwRADzSzwSQxgjRBDRByQiAQCQACwgAAAAAAAAD777774AAAAAAAACASQCBixQiQySiSjAgAjDSDhBzxCBQACwRCiyigAAAAAAAAD777774AAAAAAAADhBTQhwTwjCBAhCzTySgxQwwCgQADQDByByQBAgAAAAAAAAD777774AAAAAAAADBDTTQQRARTjxiASgwCQSSyQARwBBxjxxRhDwgAAAAAAAAAD777774AAAAAAAACCDiwBASDCTQQiBjBCgjhwwjSwTywxiCwTgxRSAAAAAAAAAD777774AAAAAAAAADggwSjzhQgSSiBgBDjDiSCiBTTzjiSgwjDzCggAAAAAAAAD777774AAAAAAAAASCjCTigDhSwQDADARiCxCyChiSyDCygTAAyCSAAAAAAAAAD777774AAAAAAAABxSQgSTRABQzTTCAgBASBgBTAiwiSATTSByBxCAAAAAAAAAD777774AAAAAAAAABwxyRRgCCAwxghQCQBTjgSQTDSwxwDjzhjgCAgAAAAAAAAD777774AAAAAAAADRSwgjxzyygSxBySQCCBgSxRxiAgABDTCjzADAgAAAAAAAAD777774AAAAAAAADCBhDyAzQCzRAiAjShDzRwiThQSSxhAiQTCBBggAAAAAAAAD777774AAAAAAAABwggCTSQzwwADCBQzRDzDwRiBQhjwARxDzxAxAgAAAAAAAAD777774AAAAAAAADywCjhCQghRjQyAQTgDSCgDwChBAQxCyhTiCwAAAAAAAAAAD777774AAAAAAAADiDDgAziAAhBRCQASDABzxBSCCBSDRCRAAhADAgAAAAAAAAD777774AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD777774AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD777774AAAAAAAAAAAAAAAABA888MMMM8sEAOdM/vcPfkAAAAAAAAAAAAAAAAAD777774AAAAAAAAAAAAAAAAACAFGEEEHGEAAEMFHPNPPMAAAAAAAAAAAAAAAAAD777774AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD777774AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD777774AAAAAAAAAAAAAAAAAAAAyIEkAABcAdosAAAAAAAAAAAAAAAAAAAAAAAD777774AAAAAAAAAAAAAAAAAAAD6gUwMAAaTOHsYIeMAAAAAAAAAAAAAAAAAAAD777774AAAAAAAAAAAAAAAAAAADw5m2k8CcYEkk1Jk8AAAAAAAAAAAAAAAAAAAD777774AAAAAAAAAAAAAAAAAAADAABICABCIBIAAAAAAAAAAAAAAAAAAAAAAAAD777774AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD777774AAAwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwAAD777774AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD777774AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD777774ABEo80U8MhcUs80s/s0UEMeE8U8EkcE08AAAAAAAAAAAAAAAAAAAAAAD777774AAW0ZfZOmKEJfFmOWPTmT1Nlacf2V1/wCTAAAAAAAAAAAAAAAAAAAAAAA++++++AAAAADDAAAAAAAAAAAADBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA++++++AATAHAXBBDBsmRAiddeCkluRBIBJpAAAAAAAAAAAAAAAAAAAAAAAAAAA++++++AABgsNBdEKA5sVDkViMQCS3djSjs8AAAAAAAAAAAAAAAAAAAAAAAAAAA++++++AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA++++++AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA++++++AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA++++++AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA++++++AARjlHTBJGFDnpPNxxbZF1AAlTJvnlRhBAAAAAAAAAAAAAAAAAAAAAAA++++++AABprB/RDnRZBJVhbPpnHTQCbpzNRb99zAAAAAAAAAAAAAAAAAAAAAAA+++++6AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAe+++++AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQ+++++++IAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEe+++++++++OOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOe+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//xAAC/9oADAMBAAIAAwAAABD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wDfDDDDDDDDDb777777rLLPPPHH3333333HHHHPPf8A+++++6yy2/xww9//AP8A/wD/AP5zCAQQRX/+YBDvfeIgjnOYwxXfMgzXf8gBHO8wxDvs8QT3/sIEmFx83nP/AP8A/wD+GsIVRz3UTJUlGiiAjOMwwzXOowzfcogDPMwwTHv8YQT/APzAI/32LgfPCb//AP8A/wD+EU/uFpvqVXy6k10+MME3zqMU3/IARz/OMEx7+EEV/wC4gHPd5xCGdmLGK/8A/wD/AP7/AP8AzST/AAE3OIWtyJRGM8yjNN/ygMczzhAO+xBBP/8AsIB3/cQQjvMRVll49/8A/wD/AK8IDP8A8lotX3A0ME3/AKzDN9yCAMc7jBEe7xhFP/4wDH99xCGe9xjBtatCyX//AP8A+s//AN4iCGc4jDFN86DFd/yAEM+zDAM//hBNf+4gDf8AeYAjnecxyohv5xrJl/8A/wD/AP8Azzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzxf/8A/wD/APzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzxf/AP8A/wD/AM88888888www4888888ww88w48w80484ww4wwwwwww48ww0888888888X//AP8A/wD888888888E08UYIA8MokQsosU8gYEYIQ84AUYo44c0QQYg8888888888X/wD/AP8A/wDPPPPPPPPFEHPLAODPHCECHDLEBFDOKMOGHMBLPEIMKAEFPPPPPPPPPPF//wD/AP8A/PPPPPPPPHMKDDKPIJJFAKAKAJJCAIKOMJANGCFOHOLJEKNPPPPPPPPPF/8A/wD/AP8AzzzzzzzzyQTjyAxzzBgwSSTDzAgBSyTjQyyASDijhgTRAhTzzzzzzzzxf/8A/wD/APzzzzzzzzxjjiCRyyzzjSQRSiSxSTgDzziTBTDgwCDTgxDzzzzzzzzzzxf/AP8A/wD/AM88888888Uok4wE8ME08og0UoYM000sE0Mwww4cQMUw0so0888888888X//AP8A/wD888888888wY8sIYMk8MkcM8UAYYcMoAoEEA88gkUEkEwIsU888888888X/wD/AP8A/wDPPPPPPPPIFCHNIHPOLKIKFLHAIPGJMGHGBLHJPGOHLEBOFPPPPPPPPPF//wD/AP8A/PPPPPPPPPEIPEKCKPMFPMDPKNGPFPOCFGDFICJNFKKCFGPPPPPPPPPPF/8A/wD/AP8AzzzzzzzzyDwCxijhSzTjjRwTDjBQDzyRBRAzSSzSyDySjDzzzzzzzzzxf/8A/wD/APzzzzzzzzzDTRyjSDzCgDChCQAQRxyBRBzAjjBQwTzDxRzxTzzzzzzzzxf/AP8A/wD/AM88888888QIYM4EQ0ccQckAU4YccEo8A80gkQU8wYsIEs40888888888X//AP8A/wD8888888888EoQcEMsEYoYEgokM4Q0kYE8U8U4kEcsk0kAc0888888888X/wD/AP8A/wDPPPPPPPPEDLGOKNEHHGAKGMHBMJGPIJNBNJAGPNJNKGEJPPPPPPPPPPF//wD/AP8A/PPPPPPPPCBHAFEBLKJAOLOEDOKOMLBAJHJEPPPPLPFJGAHPPPPPPPPPF/8A/wD/AP8AzzzzzzzzzjgyxTRTADzSBwDATRzxyxwRzRBCTCSjhgTSQRTzzzzzzzzxf/8A/wD/APzzzzzzzzzQjDCxxTijghSyxTzyXDjjzjTjghihjiSBRhCTzzzzzzzzzxf/AP8A/wD/AM88888888ksQA0Y84Ik8YE8A88BZ9M8sAYoM0AMkswYkE8U888888888X//AP8A/wD888888888QkYUsEgMU084Qw088sh58840swUYoYUIA8Q44U888888888X/wD/AP8A/wDPPPPPPPPDIFFLPOMJLMIPLHFPPODEfLKKCPBLJNOODNOPPPPPPPPPPPF//wD/AP8A/PPPPPPPPILCFFFDKALKLJMACPKZYdfKJKNNJKDFLMAPHLPPPPPPPPPPF/8A/wD/AP8AzzzzzzzzxjAhCSyTSTyAzDDDijThzSiSByRThCwxjwCBTzzzzzzzzzzxf/8A/wD/APzzzzzzzzzCyTDwTxzDijwgygRRTRwhwDxiCyBTBhjDywCzzzzzzzzzzxf/AP8A/wD/AM88888888s08AgA8cYwsQgws0AAwUU0E4Ysk00UEc8ggI88888888888X//AP8A/wD888888888UoMk0QUEMYg8kgwMw8oAEo4YU0UQkIQUYso8U8888888888X/wD/AP8A/wDPPPPPPPPMFPEHJOLPGPAMIIANKCOEKMFEANJCMBOFEPNENPPPPPPPPPF//wD/AP8A/PPPPPPPPBIIJCMOMMKCLOHEHLPJNJOOLIEBILLNKIOLDONPPPPPPPPPF/8A/wD/AP8AzzzzzzzzxwSACDxhQCDgDyhzxSByyBgCRBTCCDzhgyxAzjzzzzzzzzzxf/8A/wD/APzzzzzzzzxhRDiAwyCQzADgDShBwhCjjxjTAjRgjzhSShjDzzzzzzzzzxf/AP8A/wD/AM88888888sEwYQYE0Mo8ssEsUIcA8IMYAsocgIwow400QcU888888888X//AP8A/wD888888888QsgU844o4gcQo4kQw0UIAwQE8MwsYwEAUkow4c888888888X/wD/AP8A/wDPPPPPPPPPIMAPEBOPHOHDKGCOEMBHCDNJBECALNGDDPLFHPPPPPPPPPF//wD/AP8A/PPPPPPPPCKJBFEKGGFMNJBFAFDHHBHKDMHIPLIDJJMGFDFPPPPPPPPPF/8A/wD/AP8AzzzzzzzzxiBSRgwACCiiCyADRhAhQhCySSyRiTjjBzwBghTzzzzzzzzxf/8A/wD/APzzzzzzzzzAgTBwCiDzjzhijCRgjhBizQhzxQiCwByjgiRzTzzzzzzzzxf/AP8A/wD/AM88888888UYUQwEU4cswoAEcwUAwU8YMwEM0YgYAA8Qoss8888888888X//AP8A/wD888888888AwgwkQYQUIA0sE8cQM84MQgUogAEsMog08ssI8888888888X/wD/AP8A/wDPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPF//wD/AP8A/PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPF/8A/wD/AP8Azzzzzzzzzzzzzzzzy7X/ABp9h99d/sOZ/i3POPk888888888888888888X//AP8A/wD888888888888888888+v/AHzz/wA//wC8PtPvd999N888888888888888888X/wD/AP8A/wDPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPF//wD/AP8A/PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPF/8A/wD/AP8AzzzzzzzzzzzzzzzzzzzwfdXP7zw7mndrzzzzzzzzzzzzzzzzzzzzzzzxf/8A/wD/APzzzzzzzzzzzzzzzzzzzwF3xPfzyzvzczgWgDzzzzzzzzzzzzzzzzzzzxf/AP8A/wD/AM8888888888888888888XpOSC38C/AWszBku88888888888888888888X//AP8A/wD88888888888888888888ue8M888+c8s88+sc88888888888888888888X/wD/AP8A/wDPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPF//wD/AP8A/PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPF/8A/wD/AP8Azzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzxf/8A/wD/APzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzxf/AP8A/wD/AM858593x12kx79x/fbx3/8Abzse8d888VsfPPPPPPPPPPPPPPPPPPPPPPF//wD/AP8A/PK9Yyg7qtHJfpgPbpAwH6P7ERt6GEHgbvPPPPPPPPPPPPPPPPPPPPPPF/8A/wD/AP8Azzzzw9/zzzzzzzzzzzz93zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzxf/8A/wD/APzz+/PT7zT2981zhHQKEFMC859/tQTzzzzzzzzzzzzzzzzzzzzzzzzzzxf/AP8A/wD/AM84srY8g0380A49Y45MsmFR0NSN3I888888888888888888888888888X//AP8A/wD88888888888888888888888888888888888888888888888888888888X/wD/AP8A/wDPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPF//wD/AP8A/PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPF/8A/wD/AP8Azzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzxf/8A/wD/APzz2NXH/XvhO/1LWBRZz6GL7x1a1XxQp/Xzzzzzzzzzzzzzzzzzzzzzzxf/AP8A/wD/AM872C6AKU7F6KsGY2gscgp+8skf6MswOm88888888888888888888888X//AP8A/wD88888888888888888888888888888888888888888888888888888888f/wD/AP8A/wBPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPIf/AP8A/wD/AO/Tzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzh/8A/wD/AP8A/wD/AN9//wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/AP8A/wD/xAA7EQACAQIEAwQIBQIGAwAAAAABAhEAAwQSITEFE0EVIlRxBhAUMlBRU2EgIzNygUJSMDRwgJGxYrDB/9oACAECAQE/AP8AQC3hsRdEpaYj5xXsGM+g1ewYz6DV7BjPoNXsGM+g1ewYz6DV7BjPoNXsGM+g1ewYz6DV7BjPoNXZ+M+g1dn436DV2fjfoNXZ+N+g1dn436DV2fjfoNXZ+N+g1dn436DV2fjfoPXZ+N+g9dnY3w712djfDvXZ2N8O9dnY7w712djvDvXZ2O8O9dnY7w712djvDvXZ2O8O9dm47w712bjvDvXZuO8O9dm47w712bjvDvXZuO8O9dm4/wAO9dm4/wAO9dm4/wAO9dmY/wAO9dmY/wAO9dmY/wAO9dmY/wAM9dmY/wAM9dmY/wAM9dmY/wAM9dmY/wAM9dmY/wAM9dl4/wAM9Pw7GojO2HcKoJJjoK7U4f4lK7U4f4lK7TwHiUrtPAeJSrWJw979O6jeR/wOGcPVlF66Jn3V+IxNelvo3c4Zi2xFlJwt1pEf0Mf6TQFBay0uZSGUkEbEVwniLXxybp74Gh+Y/Eq5mVfmYpVCqFGwED14riqWbptomePeMxXD+J4THo5sv30MOh95TWKumzh7twbhdPOrWL4pfJFppjeAtDiWOsXMt8T8wRBrn2uQL5MJlmr/ABbE3Hy2RlHTSWNC9xe2MxFyPus1dx11eHLfgB2gCrWM4rfk22LRvCrVni2It3cmJXrB0gisZjLeFthiJJ91aw/H8I+It4e9+U7juEnusflPwO9YtX7T2rttXRxDKRIIr0l9GLnCrvOsy2Fc6Hqh+RoJWSstYRjbxNlx0cfitfq2/wBw/Bj8Bh2tXL0i2VBYt00+dYbieIwnETjLDQ3MJI6EE7GuJ4gPgbJAjm5TH2iawGOt4Vbk2yxYijzOJYqZVNIielcWblW7GGX3QsmuD4ZVs84jvMTH2A9XHHgWbY+7GuEvYtYQs9xASxJk1i3GNx0WhMwoNXsJYvoEuJMCAeor0rVbPEFw63A3LWSR0LV6I8Tv4/hpF8y9l8mf+4RI+B37FrEWXs3UDo4hlPUVx7gNzhWLKiWsPraf/wCH7islZKtL+bb/AHD8Vn9W3+4evFYrD4Sw9+/cCW13Y16QelL8QVsNhgUw/Un3nr0c9Gr2OuJicShXDAyAd7lcaeb1q2NlT/usJh7CYK1zETVJJYDrrRj2z8jbmdz/AJrjaEXrT9Ckf8VwnE22w62iwDrOnzFG5bDqhcZjsOtcWfmY1gP6QFpeBDSb5/hawuBw+FnIssd2O9cc9MMPhOZYwUXL4kF/6UNYHAcQ4xjGW2Gd2ablxthPVjXCeGWOGYJMNa1jV26sx3PwT0k4ngsRh3waKLrTOfohHyp7RUkUUq2v5ifuH4rP6tv9w9d6zav2ntXUDI4hlOxFYf0S4LYv80WGcgyFdsyigABArHcMGKcXFfK0QdJBrsS8d76x5GsJwyzhmDyXf5npWIw1rEWyjjyPUGn4HfnuXUI+8iuH8MbDXDcdwWiABQ4TcbFm9cuKRnzQPXjvRfhGOxBv3bTK5MtkaA3nWEwWFwdkWcPZW2g6D4Hi8dhsIs3X16KNzXEuM4nFyi/l2v7R18zTVeSTNFKRfzE/cPxWf1bf7h8Ru3bVpc1xgorGcZcgrhxlH953q6XdizMSTuTTrTLTrTJSr318x/6kQb1ETWWooATUDSoGlZdKgUQKIHqgFlrcAx1rTWo1qO8aERtQjQRuKERtQAgeXwuTpU1JqampqampqfVJkVmoGKzGaLTNZtIgVmNZtIgVmP8ApSGVMOrZQat3bd1sjWgJq6gS4yihYukSENFSpgiD67TWrdvNoX+VWrgvyjoNqS1N7J0BM/xT4gW3yKggViUWFdRAb4mMnsy55iBVn2fN3Pe6TRlcR+Z89avLfLBkbT5A1fuFyAyQR60y5hm261a5UNyYzR1rDTzzO8Gr36r+dXv8rb/ikXM6j5ms687lZFy7UiKhvMROTaaJFyyzFQGU9Ph+QvhlUbwKtYZkcMzCBVxrdy/qe7tNGzeRvy2OXzrFkdwaZutXLJtorZgZ9SWUuWu774qxZa2xd4AApLoGIL9CTV3Du1wssQaxTAKlsHagrW3ts20g1ym9oz/0zM0jB+eo3bUVlNuw4bQsRA+H5m+Zokncn1B3AgMR6pPqBIMg0WZt2J9QdwIDEeuTET6iSf8AYrZAa4oI0mnADsB8zQsOQNVBIkCdaS0zSdABuTTWXUqNDm2imssATKmN4O1LYcgGVE7AnU0QQSDVm2hQ5t2MLSW2dio3FC2QLghTC7ztS2HIBlROwJ3pbTHNsI3Jp0ZCJ67GggNgsFk56VByLjFdQRFG0wZV0loj+aFlyzDQZdydqay6hdjJ0ijYcA6qY3AOoq2AbiA7FhVxkVmHJGlLZZgDIE7Sd6Wy7ZthlOs0LLEE5liYmaNlw4Tqaa0yrmkET0NezvMSs9BNJaZpOgA3Jq7bgWVAEkdKaywBMqY3g7fALH6qedXLLy7SsSTvSBQ1srkywJJ3mozpcQETzCfOpFs4eSNAaVeULhZhBUga7zSCVScrLG+xWmAzkKZE6U9y2hRcpOTqDQyi8zAiGQmrJGS9+2kVRyiuSNMxO81rnuwVMt7p61fCArGhjUTMUrlcOYaDnoOzYe5maTIormey4YQAJ1rR+egIktI+9aW1sZiNGM0q8t3csIgxrvNWv1E/cKvXbmd1zaSanMlsqqGAAZ6UWm3fJIkkbUSPZgP/ADo5GeyGIjlimkWHBCgyNBTEe1IZ+Ve/bdARIeazKjWJI0BBpV5QuFmEFSBrvPwNHCyCgIp7hcjQAAQAP8VHCzKgg09wvAgADYD4ZbUM6g0LY5gU7HY0qMwkCiIpFBDE7CsqtGXQzEE01tg5UVkaQKETrRVCkgEEmBrRRJZRMqDr5UFUoxkyB6nRVkZW86yrkJBMiKCoFUtOtZAueZOU1y1zdYyz96KochmAT1oqhVisiK5aSV1kLM0gRiBBnzoxmMbTWVCGyzoJmhE6mBTqAwCzqBToFGx8+nwS0QLik1addAx2mDUZkSCBG8mrkMzMDSEFXWYmIoqFAk6z0ohTcfUGdRrpTweWJXY+p2AZQNlowGdswggx/NKRkueQrNpEDzrUB5eQRprSkctxPUVAdEEgRMzWeS5UgEnTyqVzzIzZd+k0/eChmGad56U40gFco+4k0W37wyRtSkKjGdToKDaRArZWBYFY0otPQUzAPbPyC0T+oSwII0/2OWlDXFU7Gja/OCjYwR5VctDmBUGkTQstmUEiCd5preXmiJjrO1cp8xX5CaFlyAdNdhOprKcs/eKCDkluuaKtpndVq6gDjLswkUy2VbIQfu00qIEZ21AMDpNctGyMugYwftTraGZSrKRsT1orZUW5U95ZJmhZVTdDAtliIpFtvcVchUQZ1oWgHZTqMpINILJR2yHux1piCTAgerLaVLZKElp61yUVrsgtlAIHnSojuq5Cv8704twe6VYdDrNOttDHKY6bzUWlS2ShJaetNZUc0CZUAjyoooshjuTp5CntKtoEe8Izfz8AskLdUkwKFxeWf7hKjyNF0LkTobcTWZUW2uYGHzEimKjn94HNBH/NG4vJ375AU+QqUZrb5wMoEjrpTwZad2OlJlNkqWAOadaTJaDksGMQAKLo1sQIKnQUGXmcwXAAYkHesyOHWYlyyk0TbCohMiZYiswCOGuBhHdHWaYW3W3NwCFANLdDNdObLIEUhy3FLXQ2hq1dXIwbcKcppGAt3QTqQIoGDNM7NExQvZEswdpkUrKGvRciYg0QMwz3Z+4MxTsOUys4c6ZauHMe7eAEbSaF7IlqDtMigyrfnNKn/o0xRrqLPcUATQvW2dgVjMIJn/eb/8QAOxEAAQMCAwUFBQYFBQAAAAAAAQACEQMEFCExBRASQVMGMlBRYRMgI0JxFSJSVHKAMDNwgaBgkaGxwf/aAAgBAwEBPwD+gDq1JneeAsTQ6gWJodQLE2/UCxNDqBYmh1AsVb9QLFW/UCxVv1AsVb9QLFW/UCxVv1AsVb9QLFW/UCxVv1QsVb9VqxVv1WrFW/VCxVv1WrFW/VCxVv1QsVb9Vqxdv1WrF2/VasXb9Vqxdv1WrF23VasXbdVqxdt1WrF23VasXbdVqxdt1WrF23VasXbdVqxdt1WrF23VasXbdVqxlt1WrGW3VasZbdVqxlt1WrGW3VasZbdVqxlt1WrGWvVasZa9Vqxlr1WrGWvWamXNCo9rG1GlziAB6lfYe1/yVRfYe1vyVRfYm1vydRfYm1vydRV7O7t/51Coz1c0gfwLu6IJpsMeZ8Rldku0lPado23rvi7pNgz87R8wRci5cSeGPaWvaHNOoIkLb+xmWhFxbiKTjDm/hPvEwCUSSSTqTvo2TqjA5zuGdFf7NurF1P2rfuVGh1N47rgVRZx1WN8yn0LOkBxiJ9SjaW9Vk0zHqCvZP9oacfemFTsqTGzUMnnyC4LF2Us/sUy3Ybp1OSWhPoWVOOMAT6lVLKk9nFSP0zkFULd1Z5AyA1Kfsa6NrUuKI9oymfiAatHn4HQr1reqyrRqOY9hlrgYIK7NdqKe1aXsa0MumDMaB48wi9ca41tBja1jc0zzpu/3Ake8/uO+h9y0uK3tGUgC/iIaG85Pkq2y6Fzs1lnXbIFNrZ5gtESFa0Sy7qtJn2ZIn+8K5tnVi2HAAIcFpR5uViON9WqdSVf1iX+zByGu7Zzc6j/oFfNqPrgNY4gDyVBuHtpfyklU69Sm4uaYk6LsixzrCpXcyBVdA9Q1drNm0LDaQNEQyszj4PwmYPgdCvWt6zK1J5Y9hlrhyK2Dt6ntW0DjDa7IFVn/AKPQrjXGq7/gVv0O/wCveqdx30O+1ta93XZRoUy+o7QBbA7MM2e5txckPuOQHdYu0XaSlY0321s8OuSIJGlNWDfhvedXOVerVdcP4HO70AD0WfsPifg+8tnOHs3t5h0q+ovFUviWlBji0ugwNSrJvDbg+ZJR2keVP/lVrmrW7xy8gtidkbi69nXvJp0DBDPmeFe39hsizaahDGNbFOmNTHIBbV2lW2nevuKmU5Mbya0aDwTs5s68t7hl29xpiI4ObgfNMrBwBQeqz/gVf0O96p3HfQ76NarQqsq0nlr2mWuGoKuO1e2q9H2RrhkiC5jYcUSSVbXhot4S2RK+0afKmVXvKlUcPdb5KlVfSfxNTdo04+8xwPorq8FZnA1pAlG+aKAptYZ4YnfY9p9rWVuKFOq0sAhvG2S1Xd5c3lY1biq57zzPgdrZXF06KbMubjoFs7ZFvaw8jjqfiPL6JiovgQmvVV3wan6D71TuO+h8Rp06lR3CxpJVpslgIdXMn8I0VIMY0Na0ADQBMcmOCY5NeqjvhVP0n/C8CMeOckEfHZUf67hQj/hISp3TulT7nI75yXLxCN0e5CjfCjdChQoUKP6U6lEEc0DIUj3DJKIhE5SgJTT4nnxIyuWSEID3DPNO0Q0CHeKK5TKJ0Wh8PmHIuQkBSDqmoGdxJBRMojJBwhN5lagqckcoWpH7UzpulSpUqdxKlTopUoFTmpzClSpUo6IfVSpClSIUqQpQOqnwA6IFHmtIWsrWN4BXJHUI81yCC+ZRmFyIXktSVqAEdCgBu5hfMs4K5hfKtCFrK1jwQD+MB4Y4wCVxfdlFwG4nQDUqSNUHCAVxCJRlSZgwpOR5FEniAjc0kxmFJ4gIUkkxyXETwxzXEY/vCk5hSQQDC4jr6o8QkyEJhS4RMZoppkGU0z5eCP7pTweXPVaE5JuQATtQVJPLJZ8LdU3LiMHcBkfVZkNEI6tULWIbCPeatCciogNkZQoPDplOnohlMAwmnOTMqPQ8Uo5kBQtSCAQeaAQGTvqUPlEafscOinJA5ZqVOilSN3NFArPdJzQlZ5qdEZhTks5G/OSp03CUJPNZyVOi5oHPwA6KM1B3eSjNeY3HVaqDK5RC0hZ6rnos88lGi5aIhHUb41XlkvoFz0Q+iiZXJZwVB/eb/8QATxAAAQMDAQMGCQoDBwQDAAAHAQIDBAAFERITITEUFSJBUZEGEBYyNFJhcXIjMDVAQlNUgaHRICQzJVBgYnOCsUNjwfBEZJKDkHDxosLh/9oACAEBAAE/Av8A+To7IYZ/qOAUq9Qxw1n3CufInqO9w/eufInqO9w/eufInqO9w/eufInqO9w/eufInqO9w/eufInqO9w/eufInqO9w/eufInqO9w/eufInqO9w/eufInqO9w/eufInqO9w/eufInqO9w/eufInqO9w/eufInqO9w/eufInqO9w/eufInqO9w/eufInqO9w/eufInqO9w/eufInqO9w/eufInqO9w/eufInqO9w/eufInqO9w/eufInqO9w/eue4vqO9w/eue4vqO9w/eue4vqO9w/eue4vqO9w/eue4vqO9w/eue4vqO9w/eue4vqO9w/eue4vqO9w/eue4vqO9w/eue4vqO9w/eue4vqO9w/eue4vqO9w/eue4vqO9w/eue4vqO9w/eue4vqO9w/eue4vqO9w/eue4vqO9w/eue4vqO9w/eue4vqO9w/eue4vqO9w/eue4vqO9w/eue4vqO9w/eue4vqO9w/eue4vqO9w/eue4vqO9w/eue4vqO9w/eue4vqO9w/eue4vqO9w/eue4vqO9w/eue4vqO9w/eue4vqO9w/eue4vqO9w/eue4vqO9w/eue4vqO9w/eue4vqO9w/eue4vqOdw/eue4vqOdw/eue4vqOdw/eue4vqOdw/eue4vqOdw/eue4vqOdw/eue4vqOdw/eue4vqOdw/eue4vqOdw/eue4vqOdw/eue4vqOdw/eue4vqOdw/eue4vqOdw/eue4vqOdw/eueovqOdw/eueovqOdw/eue4vqOdw/eueovqOdw/eueovqOd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uccbdbOOypkxy4ONttNnA6qjMhiO236opaXbbO1hPQzu9oPVUy77dktNtkauNWiIphglYwpe/wDuk8fm0cf7pWww4craQo+0ZrkcT8M1/wDkVySJ+Ha//IpKUp3JAHjdjR3v6jSVULXAH/QHeaQhCBhCQB7PEpllatSm0k9pH8LsWO9/UaSaFrgA/wBAd5pCEIGEJAHs8bsZh7+o2lVC1wAf6A7zSUpSMJAA7B4tk3r16E6u3G/xLbbX56Eq94zSG20eYhKfcMeIgKGCM0lhhBylpAPsH91Hj82jj/jE8fm0cf8AGJ4/No4/4xPH5tHH/GJ4/No4/wARLmdwrL3qisveqKy96orL3qisveqKy96orL3qisveqKy96orL3qisveqKy96orL3qisveqKy96orL3qisveqKy96orL3qisveqKy96orL3qisveqKy96orL3qisveqKy96orL3qisveqKy96orL3qisveqKy96orL3qisveqKy96orL3qisveqKy96orL3qisveqKy96orL3qisveqKy96orL3qisveqKy96orL3qisveqKy96orL3qisveqKy96orL3qisveqKy96orL3qisveqKy96orL3qisveqKy96orL3qisveqKy96orL3qisveqKy96orL3qisveqKy96orL3qisveqKy96orL3qisveqKy96orL3qisveqKy96orL3qisveqKy96orL3qisveqKy96orL3qisveqKy96orL3qisveqKy96orL3qisveqKy96orL3qisveqKy96orL3qik6usfxHj82jj/AIxPH5tHH/GJ4/No4/4xPH5tHH/GJ4/No4/xXGYuI0haUg5VjfUV0vR23CN6h88ohIJPAVDvC3pQbWhISrh/BFlTXJbiHGcIGd+P450hUeMp1IBIxUCSqTH2igBvPCnlltl1Y+ygnuq2zlyw5qSBpxw+anSFR4ynUgEjFIu09YymLqHsBpFyuBUkGGcZ9U/P3GXIamtIQ5hJCcj8/wC8jx+bRx/iv3ozX+pVt9BY+HxS7i/ynk0VI1dZpyZdIZSXwlST/wC9Vcob5Pt/sadVInXSWtXJ0gJHu/8ANO3Oe24htaAhXX7amy0RWdZ3nqFIfvTyNq2kBPUMD/zVuuRkEtOp0uD9an3B1t5MdhOXD/5p2Td4gC3tKk5/94VHfS+y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';

  @override
  Widget build(BuildContext context) {
    final qrBytes = _decodeBase64Image(_hardcodedPaymentQrBase64);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Escanea este QR para realizar el pago',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        if (qrBytes == null)
          const Text(
            'QR no configurado: agrega el base64 en _hardcodedPaymentQrBase64.',
          )
        else ...[
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                qrBytes,
                height: 220,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: OutlinedButton.icon(
              onPressed: () => _saveQrToDevice(context, qrBytes),
              icon: const Icon(Icons.download_rounded),
              label: const Text('Descargar QR'),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _saveQrToDevice(BuildContext context, Uint8List qrBytes) async {
    try {
      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar QR de pago',
        fileName: _suggestedQrFileName(_hardcodedPaymentQrBase64),
        type: FileType.custom,
        allowedExtensions: const ['png', 'jpg', 'jpeg'],
        bytes: qrBytes,
      );

      if (!context.mounted) return;

      if (savedPath == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Descarga cancelada.')));
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('QR descargado en: $savedPath')));
    } on MissingPluginException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La descarga no está disponible en esta plataforma por ahora.',
          ),
        ),
      );
    } on PlatformException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo descargar el QR: ${error.message ?? error.code}',
          ),
        ),
      );
    } on ArgumentError catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo descargar el QR: ${error.message}')),
      );
    }
  }

  String _suggestedQrFileName(String rawBase64) {
    final trimmed = rawBase64.trim();
    final lower = trimmed.toLowerCase();
    final extension = switch (true) {
      _ when lower.startsWith('data:image/png') => 'png',
      _ when lower.startsWith('data:image/jpeg') => 'jpg',
      _ when lower.startsWith('data:image/jpg') => 'jpg',
      _ => 'png',
    };

    return 'qr_pago_lagos_dent.$extension';
  }

  Uint8List? _decodeBase64Image(String rawBase64) {
    final trimmed = rawBase64.trim();
    if (trimmed.isEmpty) return null;

    final payload = trimmed.contains(',') ? trimmed.split(',').last : trimmed;

    try {
      return base64Decode(payload);
    } on FormatException {
      return null;
    }
  }
}
