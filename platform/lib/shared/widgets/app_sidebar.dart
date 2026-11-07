import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/utils/app_theme.dart';
import 'package:aidvise_platform/shared/widgets/aidvise_wordmark.dart';

/// One destination in the sidebar.
class AppSidebarItem {
  final IconData icon;
  final String label;

  /// Unread count shown as a bubble on the icon; 0 hides it.
  final int badge;
  final VoidCallback onTap;

  const AppSidebarItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge = 0,
  });
}

/// The app's navigation drawer, shared by the job-seeker and vendor shells —
/// frosted glass over the page, per docs/skeleton "Sidebar Example.jpeg".
class AppSidebar extends StatelessWidget {
  final List<AppSidebarItem> items;
  const AppSidebar({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.sidebar.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(24),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const AidViseWordmark(
                            fontSize: 26, aidColor: Colors.white),
                        IconButton(
                          icon: const Icon(Icons.menu,
                              color: Colors.white, size: 30),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    for (final item in items) ...[
                      _SidebarEntry(
                        item: item,
                        onTap: () {
                          Navigator.of(context).pop(); // close the drawer
                          item.onTap();
                        },
                      ),
                      const SizedBox(height: 36),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarEntry extends StatelessWidget {
  final AppSidebarItem item;
  final VoidCallback onTap;
  const _SidebarEntry({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            IconTheme(
              data: const IconThemeData(color: Colors.white, size: 28),
              child: BadgedIcon(icon: item.icon, count: item.badge),
            ),
            const SizedBox(width: 20),
            Text(
              item.label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

/// Icon with a small unread-count bubble; plain icon when the count is 0.
class BadgedIcon extends StatelessWidget {
  final IconData icon;
  final int count;
  const BadgedIcon({super.key, required this.icon, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return Icon(icon);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        Positioned(
          top: -4,
          right: -6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            constraints: const BoxConstraints(minWidth: 15),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Text(
              count > 9 ? '9+' : '$count',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}
