import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/ui/tokens.dart';

/// MaterialPageRoute whose pages carry the page background themselves.
/// Screens use transparent Scaffolds, so without this the route is
/// see-through during push/pop animations and the previous page stays
/// visible mid-transition.
class AppPageRoute<T> extends MaterialPageRoute<T> {
  AppPageRoute({
    required WidgetBuilder builder,
    super.settings,
    super.fullscreenDialog,
  }) : super(builder: (context) => ColoredBox(color: context.ui.bg, child: builder(context)));
}
