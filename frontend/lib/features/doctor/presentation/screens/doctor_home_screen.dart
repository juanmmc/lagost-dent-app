import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/attachments_remote_data_source.dart';
import '../../../appointments/data/appointments_repository.dart';
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
  late final ProviderSubscription<DoctorAgendaState> _agendaSubscription;

  @override
  void initState() {
    super.initState();
    _agendaSubscription = ref.listenManual<DoctorAgendaState>(
      doctorAgendaControllerProvider,
      (previous, next) {
        if (!mounted) return;
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
      },
    );
  }

  @override
  void dispose() {
    _agendaSubscription.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(doctorAgendaControllerProvider);

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
                    value: 'pending_confirmation',
                    child: Text('Por confirmar'),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'confirmed',
                    child: Text('Confirmada'),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'attended',
                    child: Text('Atendida'),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'absent',
                    child: Text('Ausente'),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'rejected',
                    child: Text('Rechazada'),
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
    final dateText = DateFormat(
      'dd/MM/yyyy HH:mm',
    ).format(appointment.scheduledAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          appointment.patientName ?? 'Paciente #${appointment.patientId}',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('$dateText · ${appointment.statusDescriptor}'),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => _DoctorAppointmentDetailScreen(
                appointmentId: appointment.id,
                initialAppointment: appointment,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DoctorAppointmentDetailScreen extends ConsumerStatefulWidget {
  const _DoctorAppointmentDetailScreen({
    required this.appointmentId,
    required this.initialAppointment,
  });

  final String appointmentId;
  final Appointment initialAppointment;

  @override
  ConsumerState<_DoctorAppointmentDetailScreen> createState() =>
      _DoctorAppointmentDetailScreenState();
}

class _DoctorAppointmentDetailScreenState
    extends ConsumerState<_DoctorAppointmentDetailScreen> {
  static const int _maxAttachmentSizeBytes = 5 * 1024 * 1024;

  bool _isUploadingRecipe = false;
  bool _isLoadingDetail = false;
  String? _recipeAttachmentId;
  String? _recipeAttachmentName;
  Appointment? _detailedAppointment;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadAppointmentDetail);
  }

  @override
  Widget build(BuildContext context) {
    final agendaState = ref.watch(doctorAgendaControllerProvider);
    final controller = ref.read(doctorAgendaControllerProvider.notifier);
    final authToken = ref.watch(
      authControllerProvider.select((state) => state.session?.token),
    );

    final fallbackAppointment = agendaState.agenda.firstWhere(
      (item) => item.id == widget.appointmentId,
      orElse: () => widget.initialAppointment,
    );
    final detailed = _detailedAppointment;
    final appointment =
        _shouldPreferAgendaAppointment(
          agendaAppointment: fallbackAppointment,
          detailedAppointment: detailed,
        )
        ? fallbackAppointment
        : (detailed ?? fallbackAppointment);

    final dateText = DateFormat(
      'dd/MM/yyyy HH:mm',
    ).format(appointment.scheduledAt);
    final receiptUrl = appointment.depositSlipAttachmentUrl?.trim();
    final receiptPath = appointment.depositSlipAttachmentPath?.trim();
    final receiptMime = appointment.depositSlipAttachmentMime?.trim();
    final receiptSource = receiptUrl != null && receiptUrl.isNotEmpty
        ? receiptUrl
        : receiptPath;
    final receiptUri = _resolveAttachmentUri(receiptSource);
    final canPreviewReceipt =
        receiptUri != null && _isImageAttachment(receiptSource, receiptMime);
    final imageHeaders = authToken == null || authToken.isEmpty
        ? null
        : <String, String>{'Authorization': 'Bearer $authToken'};

    final recipePath = appointment.recipeAttachmentPath?.trim();
    final recipeUri = _resolveAttachmentUri(recipePath);
    final canPreviewRecipe =
        recipeUri != null && _isImageAttachment(recipePath, null);

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
                    appointment.patientName ??
                        'Paciente #${appointment.patientId}',
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
                    icon: Icons.info_outline,
                    label: 'Estado',
                    value: appointment.statusDescriptor,
                  ),
                  const SizedBox(height: 10),
                  _DetailRow(
                    icon: Icons.badge_outlined,
                    label: 'ID cita',
                    value: appointment.id,
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
                        ? 'Adjunto ID: ${appointment.depositSlipAttachmentId}'
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
                            loadingBuilder: (context, child, loadingProgress) {
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
                  ] else if (receiptSource != null &&
                      receiptSource.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'El comprobante adjunto no es una imagen previsualizable.',
                    ),
                  ],
                  if (appointment.depositSlipAttachmentUrl?.isNotEmpty ==
                      true) ...[
                    const SizedBox(height: 4),
                    SelectableText(
                      'URL: ${appointment.depositSlipAttachmentUrl}',
                    ),
                  ],
                  if (appointment.depositSlipAttachmentPath?.isNotEmpty ==
                      true) ...[
                    const SizedBox(height: 4),
                    SelectableText(
                      'Ruta: ${appointment.depositSlipAttachmentPath}',
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
                  Text(
                    appointment.diagnosis?.trim().isNotEmpty == true
                        ? appointment.diagnosis!.trim()
                        : 'Pendiente',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Receta',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    appointment.prescription?.trim().isNotEmpty == true
                        ? appointment.prescription!.trim()
                        : 'Pendiente',
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
                            loadingBuilder: (context, child, loadingProgress) {
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
                  ] else if (recipePath != null && recipePath.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'El adjunto de receta no es una imagen previsualizable.',
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (agendaState.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                agendaState.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (appointment.isPendingConfirmation) ...[
            FilledButton.icon(
              onPressed: agendaState.isActionLoading
                  ? null
                  : () async {
                      await controller.confirmAppointment(
                        appointmentId: appointment.id,
                      );
                      _refreshDetailInBackground();
                    },
              icon: const Icon(Icons.verified_rounded),
              label: const Text('Confirmar cita'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: agendaState.isActionLoading
                  ? null
                  : () async {
                      final reason = await _askRequiredText(
                        context,
                        title: 'Rechazar cita',
                        label: 'Motivo de rechazo',
                        confirmText: 'Rechazar',
                      );
                      if (!context.mounted || reason == null) return;
                      await controller.rejectAppointment(
                        appointmentId: appointment.id,
                        reason: reason,
                      );
                      _refreshDetailInBackground();
                    },
              icon: const Icon(Icons.close_rounded),
              label: const Text('Rechazar cita'),
            ),
          ] else if (appointment.isConfirmed) ...[
            OutlinedButton.icon(
              onPressed: _isUploadingRecipe ? null : _pickRecipeAttachment,
              icon: _isUploadingRecipe
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file_rounded),
              label: Text(
                _isUploadingRecipe
                    ? 'Subiendo receta...'
                    : 'Adjuntar receta (opcional)',
              ),
            ),
            if (_recipeAttachmentName != null) ...[
              const SizedBox(height: 6),
              Text('Receta seleccionada: $_recipeAttachmentName'),
            ],
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: agendaState.isActionLoading
                  ? null
                  : () async {
                      final diagnosis = await _askRequiredText(
                        context,
                        title: 'Marcar como atendida',
                        label: 'Diagnóstico',
                        confirmText: 'Confirmar',
                      );
                      if (!context.mounted || diagnosis == null) return;
                      await controller.attendAppointment(
                        appointmentId: appointment.id,
                        diagnosisText: diagnosis,
                        recipeAttachmentId: _recipeAttachmentId,
                      );
                      if (!context.mounted) return;
                      _refreshDetailInBackground();
                      setState(() {
                        _recipeAttachmentId = null;
                        _recipeAttachmentName = null;
                      });
                    },
              icon: const Icon(Icons.medical_services_rounded),
              label: const Text('Marcar como atendida'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: agendaState.isActionLoading
                  ? null
                  : () async {
                      await controller.markAppointmentAbsent(
                        appointmentId: appointment.id,
                      );
                      _refreshDetailInBackground();
                    },
              icon: const Icon(Icons.person_off_rounded),
              label: const Text('Marcar inasistencia'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: agendaState.isActionLoading
                  ? null
                  : () async {
                      final reschedule = await _askRescheduleData(
                        context,
                        loadAvailableSlots: _fetchAvailableSlotsForDate,
                      );
                      if (!context.mounted || reschedule == null) return;
                      await controller.rescheduleAppointment(
                        appointmentId: appointment.id,
                        newScheduledAt: reschedule.$1,
                        reason: reschedule.$2,
                      );
                      _refreshDetailInBackground();
                    },
              icon: const Icon(Icons.update_rounded),
              label: const Text('Reprogramar cita'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickRecipeAttachment() async {
    setState(() => _isUploadingRecipe = true);
    try {
      final file = await FilePicker.platform.pickFiles(withData: true);
      final selected = file?.files.single;
      if (selected == null) return;
      if (!mounted) return;
      if (selected.size > _maxAttachmentSizeBytes) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La receta no debe superar 5MB')),
        );
        return;
      }

      final uploader = ref.read(attachmentsRemoteDataSourceProvider);
      final uploaded = await uploader.uploadAttachment(
        file: selected,
        type: 'recipe',
      );

      if (!mounted) return;
      setState(() {
        _recipeAttachmentId = uploaded.id;
        _recipeAttachmentName = selected.name;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receta adjuntada correctamente')),
      );
    } catch (error) {
      if (!mounted) return;
      final uploader = ref.read(attachmentsRemoteDataSourceProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(uploader.resolveErrorMessage(error))),
      );
    } finally {
      if (mounted) setState(() => _isUploadingRecipe = false);
    }
  }

  Future<void> _loadAppointmentDetail() async {
    setState(() => _isLoadingDetail = true);
    try {
      final repository = ref.read(appointmentsRepositoryProvider);
      final detailed = await repository.fetchAppointmentDetail(
        appointmentId: widget.appointmentId,
      );
      if (!mounted) return;
      setState(() => _detailedAppointment = detailed);
    } catch (_) {
      // Keep fallback data from agenda when detail fetch fails.
    } finally {
      if (mounted) setState(() => _isLoadingDetail = false);
    }
  }

  void _refreshDetailInBackground() {
    if (!mounted || _isLoadingDetail) return;
    Future<void>.microtask(_loadAppointmentDetail);
  }

  Future<List<TimeOfDay>> _fetchAvailableSlotsForDate(DateTime date) async {
    try {
      final repository = ref.read(appointmentsRepositoryProvider);
      final rawSlots = await repository.fetchAvailability(date: date);

      final slots =
          rawSlots
              .map((slot) => slot.toLocal())
              .map((slot) => TimeOfDay(hour: slot.hour, minute: slot.minute))
              .toSet()
              .toList()
            ..sort(
              (a, b) => (a.hour * 60 + a.minute) - (b.hour * 60 + b.minute),
            );

      return slots;
    } catch (error) {
      final repository = ref.read(appointmentsRepositoryProvider);
      throw StateError(repository.resolveErrorMessage(error));
    }
  }

  bool _shouldPreferAgendaAppointment({
    required Appointment agendaAppointment,
    required Appointment? detailedAppointment,
  }) {
    if (detailedAppointment == null) return true;

    final detailedValue = detailedAppointment.statusValue;
    final agendaValue = agendaAppointment.statusValue;
    if (detailedValue != null && agendaValue != null) {
      return detailedValue != agendaValue;
    }

    final detailedStatus = detailedAppointment.statusDescriptor
        .trim()
        .toLowerCase();
    final agendaStatus = agendaAppointment.statusDescriptor
        .trim()
        .toLowerCase();
    return detailedStatus != agendaStatus;
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
    final resolved = base.resolveUri(Uri.parse(normalizedPath));

    return resolved;
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

Future<String?> _askRequiredText(
  BuildContext context, {
  required String title,
  required String label,
  required String confirmText,
}) async {
  String currentValue = '';

  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        onChanged: (value) => currentValue = value,
        maxLines: 3,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final value = currentValue.trim();
            if (value.isEmpty) return;
            Navigator.of(context).pop(value);
          },
          child: Text(confirmText),
        ),
      ],
    ),
  );
  return result;
}

Future<(DateTime, String?)?> _askRescheduleData(
  BuildContext context, {
  required Future<List<TimeOfDay>> Function(DateTime date) loadAvailableSlots,
}) async {
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  List<TimeOfDay> availableSlots = const [];
  bool isLoadingAvailability = false;
  String? availabilityError;
  String reasonValue = '';

  final value = await showDialog<(DateTime, String?)>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Reprogramar cita'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate ?? now,
                  firstDate: now,
                  lastDate: DateTime(now.year + 2),
                );
                if (picked == null) return;
                setState(() {
                  selectedDate = picked;
                  selectedTime = null;
                  availableSlots = const [];
                  availabilityError = null;
                  isLoadingAvailability = true;
                });

                try {
                  final slots = await loadAvailableSlots(picked);
                  setState(() {
                    availableSlots = slots;
                    isLoadingAvailability = false;
                  });
                } catch (error) {
                  final message = error is StateError
                      ? error.message.toString()
                      : 'No se pudo consultar la disponibilidad';
                  setState(() {
                    availableSlots = const [];
                    isLoadingAvailability = false;
                    availabilityError = message;
                  });
                }
              },
              icon: const Icon(Icons.event_rounded),
              label: Text(
                selectedDate == null
                    ? 'Seleccionar fecha'
                    : DateFormat('dd/MM/yyyy').format(selectedDate!),
              ),
            ),
            const SizedBox(height: 8),
            if (selectedDate == null)
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.schedule_rounded),
                title: Text('Primero selecciona una fecha'),
              )
            else if (isLoadingAvailability)
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                title: Text('Consultando horas disponibles...'),
              )
            else if (availabilityError != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.error_outline),
                title: Text(availabilityError!),
              )
            else if (availableSlots.isEmpty)
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.event_busy_outlined),
                title: Text('No hay horas disponibles en esta fecha'),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedTime == null
                        ? 'Selecciona una hora'
                        : 'Hora seleccionada: ${selectedTime!.format(context)}',
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableSlots.map((slot) {
                      final selected = selectedTime == slot;
                      return ChoiceChip(
                        label: Text(slot.format(context)),
                        selected: selected,
                        onSelected: (_) => setState(() => selectedTime = slot),
                      );
                    }).toList(),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            TextField(
              onChanged: (value) => reasonValue = value,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Motivo (opcional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (selectedDate == null || selectedTime == null) return;
              final datetime = DateTime(
                selectedDate!.year,
                selectedDate!.month,
                selectedDate!.day,
                selectedTime!.hour,
                selectedTime!.minute,
              );
              final reason = reasonValue.trim();
              Navigator.of(
                context,
              ).pop((datetime, reason.isEmpty ? null : reason));
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
  return value;
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
                onPressed: state.isActionLoading
                    ? null
                    : controller.searchPatients,
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
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => _DoctorPatientAppointmentsScreen(
                              patient: patient,
                            ),
                          ),
                        );
                      },
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

class _DoctorPatientAppointmentsScreen extends ConsumerStatefulWidget {
  const _DoctorPatientAppointmentsScreen({required this.patient});

  final PatientOption patient;

  @override
  ConsumerState<_DoctorPatientAppointmentsScreen> createState() =>
      _DoctorPatientAppointmentsScreenState();
}

class _DoctorPatientAppointmentsScreenState
    extends ConsumerState<_DoctorPatientAppointmentsScreen> {
  late DateTime _selectedDate;
  bool _isLoading = false;
  bool _isBooking = false;
  String? _error;
  List<Appointment> _appointments = const [];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    Future<void>.microtask(_loadAppointments);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.patient.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Citas del paciente',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.patient.phone?.trim().isNotEmpty == true
                        ? 'Tel: ${widget.patient.phone}'
                        : 'ID: ${widget.patient.id}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _pickDate,
                          icon: const Icon(Icons.event_rounded),
                          label: Text(
                            DateFormat('dd/MM/yyyy').format(_selectedDate),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _isBooking ? null : _bookAppointment,
                        icon: _isBooking
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.add_rounded),
                        label: Text(_isBooking ? 'Agendando...' : 'Agendar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.error_outline_rounded),
                title: Text(_error!),
              ),
            )
          else if (_appointments.isEmpty)
            const Card(
              child: ListTile(
                title: Text('No hay citas para esta fecha'),
                subtitle: Text(
                  'Selecciona otra fecha o agenda una nueva cita.',
                ),
              ),
            )
          else
            ..._appointments.map((appointment) {
              final dateText = DateFormat(
                'dd/MM/yyyy HH:mm',
              ).format(appointment.scheduledAt);

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    dateText,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(appointment.statusDescriptor),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => _DoctorAppointmentDetailScreen(
                          appointmentId: appointment.id,
                          initialAppointment: appointment,
                        ),
                      ),
                    );
                  },
                ),
              );
            }),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );

    if (selected == null) return;
    setState(() => _selectedDate = selected);
    await _loadAppointments();
  }

  Future<void> _bookAppointment() async {
    setState(() => _isBooking = true);
    try {
      final auth = ref.read(authControllerProvider).session;
      if (auth == null) {
        throw StateError('Sesion no disponible');
      }

      final repository = ref.read(appointmentsRepositoryProvider);

      await _showBookForPatientDialog(
        context,
        patientId: widget.patient.id,
        loadAvailableSlots: _fetchAvailableSlotsForDate,
        onConfirm: (scheduledAt) {
          return repository.createAppointmentByDoctor(
            patientId: widget.patient.id,
            scheduledAt: scheduledAt,
          );
        },
      );

      if (!mounted) return;
      await _loadAppointments();
    } catch (error) {
      if (!mounted) return;
      final repository = ref.read(appointmentsRepositoryProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(repository.resolveErrorMessage(error))),
      );
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  Future<void> _loadAppointments() async {
    final auth = ref.read(authControllerProvider).session;
    if (auth == null) {
      setState(() {
        _error = 'Sesion no disponible';
        _appointments = const [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repository = ref.read(appointmentsRepositoryProvider);
      final list = await repository.fetchAppointmentsForDoctor(
        date: _toApiDate(_selectedDate),
        doctorId: auth.profileId,
        patientId: widget.patient.id,
        order: 'desc',
      );

      if (!mounted) return;
      setState(() {
        _appointments = list;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      final repository = ref.read(appointmentsRepositoryProvider);
      setState(() {
        _appointments = const [];
        _isLoading = false;
        _error = repository.resolveErrorMessage(error);
      });
    }
  }

  String _toApiDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<List<TimeOfDay>> _fetchAvailableSlotsForDate(DateTime date) async {
    try {
      final repository = ref.read(appointmentsRepositoryProvider);
      final rawSlots = await repository.fetchAvailability(date: date);

      final slots =
          rawSlots
              .map((slot) => slot.toLocal())
              .map((slot) => TimeOfDay(hour: slot.hour, minute: slot.minute))
              .toSet()
              .toList()
            ..sort(
              (a, b) => (a.hour * 60 + a.minute) - (b.hour * 60 + b.minute),
            );

      return slots;
    } catch (error) {
      final repository = ref.read(appointmentsRepositoryProvider);
      throw StateError(repository.resolveErrorMessage(error));
    }
  }
}

Future<void> _showBookForPatientDialog(
  BuildContext context, {
  required String patientId,
  required Future<List<TimeOfDay>> Function(DateTime date) loadAvailableSlots,
  required Future<void> Function(DateTime scheduledAt) onConfirm,
}) async {
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  List<TimeOfDay> availableSlots = const [];
  bool isLoadingAvailability = false;
  String? availabilityError;

  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
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
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate ?? now,
                  firstDate: now,
                  lastDate: DateTime(now.year + 2),
                );
                if (picked == null) return;

                setState(() {
                  selectedDate = picked;
                  selectedTime = null;
                  availableSlots = const [];
                  availabilityError = null;
                  isLoadingAvailability = true;
                });

                try {
                  final slots = await loadAvailableSlots(picked);
                  setState(() {
                    availableSlots = slots;
                    isLoadingAvailability = false;
                  });
                } catch (error) {
                  final message = error is StateError
                      ? error.message.toString()
                      : 'No se pudo consultar la disponibilidad';
                  setState(() {
                    availableSlots = const [];
                    isLoadingAvailability = false;
                    availabilityError = message;
                  });
                }
              },
              icon: const Icon(Icons.event),
              label: Text(
                selectedDate == null
                    ? 'Seleccionar fecha'
                    : DateFormat('dd/MM/yyyy').format(selectedDate!),
              ),
            ),
            const SizedBox(height: 8),
            if (selectedDate == null)
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.schedule_rounded),
                title: Text('Primero selecciona una fecha'),
              )
            else if (isLoadingAvailability)
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                title: Text('Consultando horas disponibles...'),
              )
            else if (availabilityError != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.error_outline),
                title: Text(availabilityError!),
              )
            else if (availableSlots.isEmpty)
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.event_busy_outlined),
                title: Text('No hay horas disponibles en esta fecha'),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedTime == null
                        ? 'Selecciona una hora'
                        : 'Hora seleccionada: ${selectedTime!.format(context)}',
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableSlots.map((slot) {
                      final selected = selectedTime == slot;
                      return ChoiceChip(
                        label: Text(slot.format(context)),
                        selected: selected,
                        onSelected: (_) => setState(() => selectedTime = slot),
                      );
                    }).toList(),
                  ),
                ],
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
              if (selectedDate == null || selectedTime == null) return;

              final scheduledAt = DateTime(
                selectedDate!.year,
                selectedDate!.month,
                selectedDate!.day,
                selectedTime!.hour,
                selectedTime!.minute,
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
