import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/models/user_role.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/appointments/presentation/controllers/doctor_agenda_controller.dart';
import '../../features/appointments/presentation/controllers/patient_appointments_controller.dart';
import '../router/app_router.dart';

final firebaseMessagingServiceProvider =
    Provider<FirebaseMessagingService>((ref) {
  return FirebaseMessagingService(ref);
});

class FirebaseMessagingService {
  FirebaseMessagingService(this._ref);

  final Ref _ref;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Initialize Firebase Messaging
  /// This should be called early in app startup
  Future<void> initialize() async {
    if (kDebugMode) {
      debugPrint('🔥 [FCM] Initializing Firebase Messaging Service');
    }

    // Request user notification permissions (iOS only, Android auto-grants)
    await _messaging.requestPermission(
      alert: true,
      announcement: true,
      badge: true,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background message taps
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Get initial message if app was closed
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      if (kDebugMode) {
        debugPrint(
          '🔥 [FCM] App opened from notification (was closed): ${initialMessage.messageId}',
        );
      }
      _handleMessageOpenedApp(initialMessage);
    }

    // Handle token refresh
    _messaging.onTokenRefresh.listen(_handleTokenRefresh);

    if (kDebugMode) {
      debugPrint('✅ [FCM] Firebase Messaging Service initialized');
    }
  }

  /// Get the current FCM token
  Future<String?> getToken() async {
    try {
      final token = await _messaging.getToken();
      if (kDebugMode) {
        debugPrint('🔥 [FCM] Token obtained: ${token?.substring(0, 20)}...');
      }
      return token;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [FCM] Error getting token: $e');
      }
      return null;
    }
  }

  /// Handle foreground messages (app in focus)
  void _handleForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('🔥 [FCM] Foreground message received: ${message.messageId}');
      debugPrint('   Title: ${message.notification?.title}');
      debugPrint('   Body: ${message.notification?.body}');
      debugPrint('   Data: ${message.data}');
    }

    // Show notification or handle in-app
    // The notification will be displayed automatically by Firebase
    // You can also show a custom in-app notification here if desired
  }

  /// Handle notification tap when app is in background/closed
  void _handleMessageOpenedApp(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint(
        '🔥 [FCM] Message opened from notification: ${message.messageId}',
      );
      debugPrint('   Data: ${message.data}');
    }

    // Navigate based on notification data
    _navigateFromNotification(message.data);
  }

  /// Handle token refresh
  void _handleTokenRefresh(String newToken) {
    if (kDebugMode) {
      debugPrint('🔥 [FCM] Token refreshed: ${newToken.substring(0, 20)}...');
    }

    // Notify that token has refreshed
    // The device token service will handle re-registering with backend
  }

  /// Navigate to the appropriate screen based on notification data
  void _navigateFromNotification(Map<String, dynamic> data) {
    try {
      final appointmentId = data['appointment_id'];
      final event = data['event'];

      if (appointmentId != null) {
        if (kDebugMode) {
          debugPrint(
            '🧭 [FCM] Navigating to appointment: $appointmentId (event: $event)',
          );
        }

        // Route to appointment detail entrypoint in router.
        // The corresponding home screen opens detail from initialAppointmentId.
        final authState = _ref.read(authControllerProvider);
        if (authState.isAuthenticated) {
          _ref.read(appRouterProvider).push('/appointments/$appointmentId');
        } else {
          _ref.read(appRouterProvider).pushReplacement('/');
        }

        // Refresh appointments data to show updated appointment status
        // Import the appropriate controller based on auth state
        final authState2 = _ref.read(authControllerProvider);
        if (authState2.session?.role.isPatient ?? false) {
          _refreshPatientAppointments();
        } else {
          _refreshDoctorAppointments();
        }
      } else if (kDebugMode) {
        debugPrint('⚠️ [FCM] Notification has no appointment_id');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [FCM] Error navigating from notification: $e');
      }
    }
  }

  /// Refresh patient appointments after notification
  void _refreshPatientAppointments() {
    try {
      if (kDebugMode) {
        debugPrint('🔄 [FCM] Refreshing patient appointments');
      }
      final _ = _ref.refresh(patientAppointmentsControllerProvider);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [FCM] Error refreshing patient appointments: $e');
      }
    }
  }

  /// Refresh doctor appointments after notification
  void _refreshDoctorAppointments() {
    try {
      if (kDebugMode) {
        debugPrint('🔄 [FCM] Refreshing doctor appointments');
      }
      final _ = _ref.refresh(doctorAgendaControllerProvider);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [FCM] Error refreshing doctor appointments: $e');
      }
    }
  }
}
