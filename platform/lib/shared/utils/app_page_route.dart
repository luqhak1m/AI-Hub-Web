import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/widgets/app_background.dart';

/// MaterialPageRoute whose pages carry the app background themselves.
/// Screens use transparent Scaffolds (the texture is app-wide), so without
/// this the route is see-through during push/pop animations and the previous
/// page stays visible mid-transition.
class AppPageRoute<T> extends MaterialPageRoute<T> {
  AppPageRoute({
    required WidgetBuilder builder,
    super.settings,
    super.fullscreenDialog,
  }) : super(builder: (context) => AppBackground(child: builder(context)));
}
