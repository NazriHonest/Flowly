import 'package:flutter/widgets.dart';

abstract final class AppLayout {
  static const double scrollContentGap = 24;
  static const double floatingActionGap = 88;

  /// Bottom space for full-screen routes that sit directly above the system
  /// navigation area. Do not use inside the tab shell, whose navigation bar
  /// already consumes that inset.
  static double safeScrollBottom(
    BuildContext context, {
    bool hasFloatingActionButton = false,
  }) {
    final contentGap = hasFloatingActionButton
        ? floatingActionGap
        : scrollContentGap;
    return contentGap + MediaQuery.viewPaddingOf(context).bottom;
  }
}
