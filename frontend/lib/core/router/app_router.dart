import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/screens/doctor_login_screen.dart';
import '../../features/auth/presentation/screens/patient_login_screen.dart';
import '../../features/auth/presentation/screens/patient_register_screen.dart';
import '../../features/auth/presentation/screens/welcome_screen.dart';
import '../../features/auth/domain/models/user_role.dart';
import '../../features/doctor/presentation/screens/doctor_home_screen.dart';
import '../../features/patient/presentation/screens/patient_home_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  ref.watch(
    authControllerProvider.select(
      (state) =>
          '${state.isInitialized}|${state.isAuthenticated}|${state.session?.role.name ?? ''}',
    ),
  );
  final authState = ref.read(authControllerProvider);

  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const WelcomeScreen()),
      GoRoute(
        path: '/login/patient',
        builder: (context, state) => const PatientLoginScreen(),
      ),
      GoRoute(
        path: '/login/doctor',
        builder: (context, state) => const DoctorLoginScreen(),
      ),
      GoRoute(
        path: '/register/patient',
        builder: (context, state) => const PatientRegisterScreen(),
      ),
      GoRoute(
        path: '/patient/home',
        builder: (context, state) => const PatientHomeScreen(),
      ),
      GoRoute(
        path: '/doctor/home',
        builder: (context, state) => const DoctorHomeScreen(),
      ),
      GoRoute(
        path: '/appointments/:id',
        builder: (context, state) {
          final appointmentId = state.pathParameters['id'];
          final role = authState.session?.role;

          if (appointmentId == null || appointmentId.isEmpty) {
            return role?.isPatient == true
                ? const PatientHomeScreen()
                : const DoctorHomeScreen();
          }

          if (role?.isPatient == true) {
            return PatientHomeScreen(initialAppointmentId: appointmentId);
          }

          return DoctorHomeScreen(initialAppointmentId: appointmentId);
        },
      ),
    ],
    redirect: (context, state) {
      final path = state.uri.path;
      final isPatientArea = path.startsWith('/patient/');
      final isDoctorArea = path.startsWith('/doctor/');
      final isAppointmentsArea = path.startsWith('/appointments/');
      final isProtected = isPatientArea || isDoctorArea || isAppointmentsArea;
      final isAuthScreen =
          path == '/' ||
          path == '/login/patient' ||
          path == '/login/doctor' ||
          path == '/register/patient';

      String? destination;

      if (!authState.isInitialized) {
        _traceRedirect(path, null, authState, 'not-initialized');
        return null;
      }

      if (!authState.isAuthenticated) {
        if (isProtected) {
          destination = '/';
          _traceRedirect(path, destination, authState, 'guest-protected');
          return destination;
        }
        _traceRedirect(path, null, authState, 'guest-public');
        return null;
      }

      if (authState.isAuthenticated) {
        if (authState.session!.role.isPatient && isDoctorArea) {
          destination = '/patient/home';
          _traceRedirect(path, destination, authState, 'patient-in-doctor-area');
          return destination;
        }
        if (authState.session!.role.isDoctor && isPatientArea) {
          destination = '/doctor/home';
          _traceRedirect(path, destination, authState, 'doctor-in-patient-area');
          return destination;
        }
        if (isAuthScreen) {
          destination = authState.session!.role.isPatient
              ? '/patient/home'
              : '/doctor/home';
          _traceRedirect(path, destination, authState, 'authed-on-auth-screen');
          return destination;
        }
      }

      _traceRedirect(path, null, authState, 'allow');
      return null;
    },
  );
});

void _traceRedirect(
  String path,
  String? destination,
  AuthState authState,
  String reason,
) {
  if (!kDebugMode) return;

  final role = authState.session?.role.name ?? '-';
  debugPrint(
    '🧭 [ROUTER] path=$path -> ${destination ?? 'stay'} | initialized=${authState.isInitialized} | authenticated=${authState.isAuthenticated} | role=$role | reason=$reason',
  );
}
