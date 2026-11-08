import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:aidvise_platform/shared/api/api_service.dart';
import 'package:aidvise_platform/shared/utils/session.dart';
import 'package:aidvise_platform/user/utils/paywall.dart';
import 'package:aidvise_platform/shared/utils/app_theme.dart';
import 'package:aidvise_platform/shared/ui/tokens.dart';

/// Full-screen career advisor chat. Opened from the bot button on the
/// results screen via [advisorChatRoute], which slides it in over the page.
class AdvisorChatScreen extends StatefulWidget {
  final int sessionId;

  /// Sent automatically when the chat opens (e.g. "Explain my results").
  final String? openingMessage;

  const AdvisorChatScreen({
    super.key,
    required this.sessionId,
    this.openingMessage,
  });

  @override
  State<AdvisorChatScreen> createState() => _AdvisorChatScreenState();
}

/// Slides the chat in from the right, taking over the whole screen.
Route<void> advisorChatRoute({required int sessionId, String? openingMessage}) {
  return PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, __, ___) => ColoredBox(
      color: Ui.bg,
      child: AdvisorChatScreen(
          sessionId: sessionId, openingMessage: openingMessage),
    ),
    transitionsBuilder: (_, animation, __, child) => SlideTransition(
      position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: child,
    ),
  );
}

class _AdvisorChatScreenState extends State<AdvisorChatScreen> {
  final List<Map<String, String>> _history = [];
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final opening = widget.openingMessage;
    if (opening != null && opening.isNotEmpty) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _sendText(opening));
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() => _sendText(_input.text.trim());

  Future<void> _sendText(String text) async {
    if (text.isEmpty || _loading) return;

    final outgoing = List<Map<String, String>>.from(_history);
    setState(() {
      _history.add({'role': 'user', 'content': text});
      _input.clear();
      _loading = true;
      _error = null;
    });
    _scrollToBottom();

    try {
      final reply = await ApiService.sendChatMessage(
        sessionId: widget.sessionId,
        message: text,
        history: outgoing,
      );
      setState(() => _history.add({'role': 'assistant', 'content': reply}));
    } on ApiException catch (e) {
      if (mounted && handleSessionExpiry(context, e)) return;
      if (mounted && handleUpgradeRequired(context, e)) {
        // Put the unsent message back in the box and drop it from history.
        setState(() {
          _history.removeLast();
          _input.text = text;
        });
        return;
      }
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not reach the server. Check your connection.');
    } finally {
      if (mounted) setState(() => _loading = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
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
        title: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                  color: AppTheme.primary, shape: BoxShape.circle),
              child: const Icon(Icons.smart_toy,
                  color: Colors.white, size: 17),
            ),
            const SizedBox(width: 10),
            const Text('Career Advisor',
                style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Expanded(child: _buildChatArea()),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Ui.bad, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildChatArea() {
    if (_history.isEmpty && !_loading) return _buildEmptyChat();
    return ListView.builder(
      controller: _scroll,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      itemCount: _history.length + (_loading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _history.length) return _buildTypingIndicator();
        final msg = _history[index];
        return _buildBubble(msg['role']!, msg['content']!);
      },
    );
  }

  Widget _buildEmptyChat() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.smart_toy_outlined, size: 44, color: Ui.surface3),
            SizedBox(height: 14),
            Text(
              'Ask anything about your results',
              style: TextStyle(
                  color: AppTheme.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              '"Why did I get this?" · "What skills should I build?"',
              style: TextStyle(color: Ui.muted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble(String role, String content) {
    final isUser = role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        decoration: BoxDecoration(
          color: isUser ? AppTheme.primary : AppTheme.cardGrey,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isUser ? 14 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 14),
          ),
          border: isUser
              ? null
              : Border.all(color: AppTheme.cardHairline, width: 0.8),
        ),
        child: isUser
            ? Text(
                content,
                style: const TextStyle(
                    color: Colors.white, fontSize: 14, height: 1.45),
              )
            : MarkdownBody(
                data: content,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(
                      color: AppTheme.primary, fontSize: 14, height: 1.45),
                  strong: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                  em: const TextStyle(
                      color: AppTheme.primary,
                      fontStyle: FontStyle.italic,
                      fontSize: 14),
                  listBullet:
                      const TextStyle(color: AppTheme.primary, fontSize: 14),
                  blockquote:
                      const TextStyle(color: Ui.muted, fontSize: 14),
                ),
              ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardGrey,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.cardHairline, width: 0.8),
        ),
        child: const SizedBox(width: 40, height: 14, child: DotsIndicator()),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, 10 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Ui.line, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.enter): _send,
              },
              child: TextField(
                controller: _input,
                style: const TextStyle(color: AppTheme.primary, fontSize: 14),
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Ask about your results...',
                  hintStyle: const TextStyle(color: Ui.muted),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _send,
            child: Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.arrow_upward, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

/// Three pulsing dots shown while the advisor is composing a reply.
class DotsIndicator extends StatefulWidget {
  const DotsIndicator({super.key});

  @override
  State<DotsIndicator> createState() => _DotsIndicatorState();
}

class _DotsIndicatorState extends State<DotsIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final delay = i / 3;
            final t = (_controller.value - delay).clamp(0.0, 1.0);
            final opacity = (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.3, 1.0);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: opacity),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}
