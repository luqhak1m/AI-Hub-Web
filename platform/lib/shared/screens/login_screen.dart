import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/api/api_service.dart';
import 'package:aidvise_platform/shared/screens/register_screen.dart';
import 'package:aidvise_platform/shared/ui/components.dart';
import 'package:aidvise_platform/shared/ui/tokens.dart';
import 'package:aidvise_platform/shared/utils/app_page_route.dart';

class LoginScreen extends StatefulWidget {
  /// Where a successful login goes: the platform's gate, which picks the
  /// admin, employer or job seeker area by account type.
  final WidgetBuilder destination;

  const LoginScreen({super.key, required this.destination});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  /// Set when the app ended the session for the user (expiry, idle timeout).
  String? _notice;

  @override
  void initState() {
    super.initState();
    _loadNotice();
  }

  Future<void> _loadNotice() async {
    final notice = await ApiService.takeLogoutNotice();
    if (mounted && notice != null) setState(() => _notice = notice);
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      await ApiService.login(
        username: _usernameCtrl.text.trim(),
        password: _passwordCtrl.text,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        AppPageRoute(builder: widget.destination),
      );
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Could not reach the server. Check your connection.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.ui.bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Panel(
              padding: const EdgeInsets.all(28),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(alignment: Alignment.centerLeft, child: Wordmark(size: 26)),
                    const SizedBox(height: 22),
                    const Eyebrow('Welcome back'),
                    Text('Sign in', style: context.ui.display(Ui.step3)),
                    const SizedBox(height: 18),
                    if (_notice != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.ui.brandSoft,
                          borderRadius: BorderRadius.circular(Ui.radiusSm),
                        ),
                        child: Text(_notice!, style: context.ui.body(size: Ui.step_1, color: context.ui.brand)),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _usernameCtrl,
                      style: context.ui.body(),
                      decoration: _inputDecoration('Username'),
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Enter your username';
                        if (v.trim().length < 3) return 'At least 3 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _obscurePassword,
                      style: context.ui.body(),
                      decoration: _inputDecoration('Password').copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility,
                              size: 18, color: context.ui.muted),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(_errorMessage!, style: context.ui.body(size: Ui.step_1, color: context.ui.bad)),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 44,
                      child: UiButton('Sign in', busy: _loading, onPressed: _submit),
                    ),
                    const SizedBox(height: 16),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text("Don't have an account? ", style: context.ui.meta),
                      Clickable(
                        onTap: () => Navigator.of(context).push(
                          AppPageRoute(builder: (_) => const RegisterScreen()),
                        ),
                        child: Text('Register',
                            style: context.ui.body(size: Ui.step_1, weight: FontWeight.w700, color: context.ui.brand)),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        labelStyle: context.ui.body(color: context.ui.muted),
        isDense: true,
        filled: true,
        fillColor: context.ui.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Ui.radiusSm), borderSide: BorderSide(color: context.ui.line)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Ui.radiusSm), borderSide: BorderSide(color: context.ui.brandFill)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Ui.radiusSm), borderSide: BorderSide(color: context.ui.bad)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Ui.radiusSm), borderSide: BorderSide(color: context.ui.bad)),
      );
}
