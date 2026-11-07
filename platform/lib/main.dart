import 'package:flutter/material.dart';
import 'package:aidvise_platform/admin/admin_gate.dart';
import 'package:aidvise_platform/shared/app_frame.dart';
import 'package:aidvise_platform/shared/screens/login_screen.dart';
import 'package:aidvise_platform/shared/utils/session.dart';

/// The AidVise web platform. Today it is the admin panel only; the job
/// seeker (lib/user/) and employer (lib/vendor/) areas will join it, each
/// behind its own gate, with login routing by account type.
///
///   flutter run -d chrome
///   flutter build web --dart-define=BASE_HOST=https://api.example.com
void main() {
  loginScreenBuilder = (_) => LoginScreen(destination: (_) => const AdminGate());
  runApp(const AppFrame(title: 'AidVise Admin', home: AdminGate()));
}
