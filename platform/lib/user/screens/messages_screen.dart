import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/api/api_service.dart';
import 'package:aidvise_platform/shared/utils/session.dart';
import 'package:aidvise_platform/shared/utils/app_theme.dart';
import 'package:aidvise_platform/shared/utils/app_page_route.dart';
import 'package:aidvise_platform/shared/widgets/app_card.dart';
import 'package:aidvise_platform/user/screens/employer_chat_screen.dart';

/// Message threads, one per company the user has applied to. The list is
/// real; the conversations behind it are placeholders until the messaging
/// service exists (see [EmployerChatScreen]).
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<Map<String, dynamic>> _applications = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final applications = await ApiService.getMyApplications();
      if (!mounted) return;
      setState(() {
        _applications = applications;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted && handleSessionExpiry(context, e)) return;
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load your conversations.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Messages',
            style: TextStyle(
                color: AppTheme.primary,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null
              ? Center(
                  child: Text(_error!,
                      style: const TextStyle(color: Color(0xFF888888))))
              : _applications.isEmpty
                  ? _buildEmpty()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
                          child: Text(
                            'Messaging is not live yet — these threads open a '
                            'preview of the coming chat.',
                            style: TextStyle(
                                color: Color(0xFF888888),
                                fontSize: 12.5,
                                height: 1.45),
                          ),
                        ),
                        ..._applications.map(_buildThread),
                      ],
                    ),
    );
  }

  Widget _buildEmpty() => const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.forum_outlined, size: 40, color: Color(0xFFCCCCCC)),
              SizedBox(height: 12),
              Text('No conversations yet.',
                  style: TextStyle(color: AppTheme.primary, fontSize: 15)),
              SizedBox(height: 6),
              Text('Apply to a job and you can message the employer here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF888888), fontSize: 13)),
            ],
          ),
        ),
      );

  Widget _buildThread(Map<String, dynamic> application) {
    final company = application['company'] as String? ?? 'Employer';
    final jobTitle = application['job_title'] as String? ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        compact: true,
        icon: Icons.business,
        title: company,
        description: jobTitle,
        onTap: () => Navigator.of(context).push(
          AppPageRoute(
            builder: (_) => EmployerChatScreen(
              company: company,
              applicationId: application['id'] as int,
            ),
          ),
        ),
      ),
    );
  }
}
