import 'package:flutter/widgets.dart';

import 'info_pages_config.dart';

/// Route used to open Petunjuk / Tentang from Home.
///
/// Reproduces the React `.astorya-screen-enter` effect: a 180 ms opacity fade
/// with cubic-bezier(0.22, 1, 0.36, 1). Nothing else moves. The fade is skipped
/// when the platform asks for reduced motion.
///
/// Usage:
/// ```dart
/// Navigator.of(context).push(
///   InfoPageRoute<void>(builder: (_) => TentangPage()),
/// );
/// ```
class InfoPageRoute<T> extends PageRouteBuilder<T> {
  InfoPageRoute({
    required WidgetBuilder builder,
    super.settings,
  }) : super(
          pageBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) =>
              builder(context),
          transitionDuration: InfoPagesConfig.screenEnterDuration,
          reverseTransitionDuration: InfoPagesConfig.screenEnterDuration,
          transitionsBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget child,
          ) {
            if (MediaQuery.disableAnimationsOf(context)) return child;
            return FadeTransition(
              opacity: animation.drive(
                CurveTween(curve: InfoPagesConfig.interactionCurve),
              ),
              child: child,
            );
          },
        );
}
