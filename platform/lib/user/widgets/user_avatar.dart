import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/api/api_service.dart';
import 'package:aidvise_platform/shared/utils/app_theme.dart';

/// Profile pictures shipped with the app, keyed by username.
///
/// Only a fallback now that accounts can upload their own: it keeps the demo
/// accounts looking right on a fresh database. An uploaded picture always
/// wins.
const _bundledAvatars = <String, String>{
  'testuser2': 'assets/images/testuser2_pfp.png',
};

/// Round profile picture. Shows the user's uploaded photo when [avatarUrl] is
/// set, a bundled demo photo for known demo accounts, and a neutral person
/// placeholder otherwise.
class UserAvatar extends StatefulWidget {
  final String? username;

  /// Path from the API (`avatar_url`); the bytes are fetched with auth.
  final String? avatarUrl;
  final double size;

  const UserAvatar({
    super.key,
    required this.username,
    this.avatarUrl,
    this.size = 52,
  });

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  Future<Uint8List>? _uploaded;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(UserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.avatarUrl != widget.avatarUrl) _load();
  }

  void _load() {
    _uploaded = widget.avatarUrl == null ? null : ApiService.getAvatar();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: Color(0xFFCFCFCF),
        shape: BoxShape.circle,
      ),
      child: _uploaded == null
          ? _bundledOrPlaceholder(size)
          : FutureBuilder<Uint8List>(
              future: _uploaded,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Image.memory(snapshot.data!,
                      fit: BoxFit.cover,
                      width: size,
                      height: size,
                      cacheWidth: (size * 3).round());
                }
                // Loading or failed: fall back rather than flash an error.
                return _bundledOrPlaceholder(size);
              },
            ),
    );
  }

  Widget _bundledOrPlaceholder(double size) {
    final asset = _bundledAvatars[(widget.username ?? '').trim().toLowerCase()];
    if (asset == null) {
      return Icon(Icons.person, color: AppTheme.primary, size: size * 0.58);
    }
    return Image.asset(
      asset,
      fit: BoxFit.cover,
      width: size,
      height: size,
      cacheWidth: (size * 3).round(),
      errorBuilder: (_, __, ___) =>
          Icon(Icons.person, color: AppTheme.primary, size: size * 0.58),
    );
  }
}
