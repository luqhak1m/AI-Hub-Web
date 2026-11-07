import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/api/api_service.dart';
import 'package:aidvise_platform/shared/utils/app_theme.dart';
import 'package:aidvise_platform/shared/utils/app_page_route.dart';

/// Root navigator, so session handling can navigate without a screen's
/// BuildContext — a dead session must eject the user even when the call that
/// discovered it was fired by a screen that ignores errors.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// The screen a signed-out user lands on. Set once by main(), which knows
/// where a successful login should go.
late WidgetBuilder loginScreenBuilder;

/// One expiry prompt at a time — a screen with several in-flight calls can
/// surface the same 401 more than once.
bool _promptOpen = false;

/// Wire the API layer's 401 hook to the expiry prompt. Called once at startup.
void installSessionGuard() {
  ApiService.onUnauthorized = () {
    final context = appNavigatorKey.currentContext;
    if (context != null) _promptSessionExpired(context);
  };
}

/// Call at the top of an `on ApiException catch` block. If the error is a
/// session expiry (401), tells the user with an alert and offers to take
/// them to the login screen, then returns true so the caller bails out;
/// otherwise returns false and the caller handles the error as usual.
bool handleSessionExpiry(BuildContext context, ApiException e) {
  if (e.statusCode != 401) return false;
  _promptSessionExpired(context);
  return true;
}

/// Ends the session immediately, with [notice] explaining why on the login
/// screen. Used when there is nothing to ask about — no token at all, or the
/// idle timeout has passed.
Future<void> forceLogout(String notice) async {
  await ApiService.logout(notice: notice);
  appNavigatorKey.currentState?.pushAndRemoveUntil(
    AppPageRoute(builder: loginScreenBuilder),
    (route) => false,
  );
}

Future<void> _promptSessionExpired(BuildContext context) async {
  if (_promptOpen) return;
  _promptOpen = true;
  try {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          'Session expired',
          style: TextStyle(
              color: AppTheme.primary,
              fontSize: 17,
              fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'You have been signed out for security because your session '
          'expired. Log in again to pick up where you left off.',
          style:
              TextStyle(color: AppTheme.primary, fontSize: 13.5, height: 1.5),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Log In Again'),
          ),
        ],
      ),
    );
    // The session is gone either way — acknowledging is the only option, so
    // a signed-out user is never left sitting inside the app.
    await ApiService.logout(
        notice: 'You have been logged out. Please log in again.');
    appNavigatorKey.currentState?.pushAndRemoveUntil(
      AppPageRoute(builder: loginScreenBuilder),
      (route) => false,
    );
  } finally {
    _promptOpen = false;
  }
}
