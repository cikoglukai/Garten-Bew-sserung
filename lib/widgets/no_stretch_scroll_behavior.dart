import 'package:flutter/material.dart';

/// Scroll behavior that drops the Android stretch overscroll effect, which
/// otherwise makes lists visibly stretch when you drag past the edge.
///
/// Applied by wrapping a scrollable in `ScrollConfiguration(behavior: const
/// NoStretchScrollBehavior(), child: …)` — see HomeScreen and SettingsScreen.
class NoStretchScrollBehavior extends MaterialScrollBehavior {
  const NoStretchScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    // Return the child unchanged => no glow/stretch indicator is drawn.
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    // Clamping physics stop the list dead at the edge (no bounce/stretch).
    return const ClampingScrollPhysics();
  }
}
