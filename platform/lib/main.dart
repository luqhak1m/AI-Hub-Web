import 'package:flutter/material.dart';
import 'package:aidvise_platform/app_gate.dart';
import 'package:aidvise_platform/shared/app_frame.dart';
import 'package:aidvise_platform/shared/screens/login_screen.dart';
import 'package:aidvise_platform/shared/utils/session.dart';

/// The AidVise web platform: job seekers (lib/user/), employers
/// (lib/vendor/) and administrators (lib/admin/) behind one login. AppGate
/// opens the right area for the signed-in account.
///
///   flutter run -d chrome
///   flutter build web --dart-define=BASE_HOST=https://api.example.com
void main() {
  loginScreenBuilder = (_) => LoginScreen(destination: (_) => const AppGate());
  runApp(const AppFrame(title: 'AidVise', home: AppGate()));
}
