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
  final authState = ref.watch(authControllerProvider);

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
    ],
    redirect: (context, state) {
      final location = state.uri.toString();
      final isPublic =
          location == '/' ||
          location == '/login/patient' ||
          location == '/login/doctor' ||
          location == '/register/patient';

      if (!authState.isInitialized) return null;

      if (!authState.isAuthenticated && !isPublic) {
        return '/';
      }

      if (authState.isAuthenticated) {
        if (authState.session!.role.isPatient &&
            location.startsWith('/doctor/')) {
          return '/patient/home';
        }
        if (authState.session!.role.isDoctor &&
            location.startsWith('/patient/')) {
          return '/doctor/home';
        }
        if (isPublic) {
          return authState.session!.role.isPatient
              ? '/patient/home'
              : '/doctor/home';
        }
      }

      return null;
    },
  );
});
