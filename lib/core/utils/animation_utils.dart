import 'package:flutter/material.dart';

/// Returns true when the platform has NOT requested reduced motion.
///
/// Read via `MediaQuery.disableAnimationsOf(context)` — automatically
/// reflects the OS accessibility setting "Reduce motion" (iOS) /
/// "Remove animations" (Android). Every custom animated widget in this
/// app calls this helper before starting an animation loop ([IP-0044]).
bool animationsEnabled(BuildContext context) =>
    !MediaQuery.disableAnimationsOf(context);

/// Convenience duration multiplier: returns [d] when animations are
/// enabled, or [Duration.zero] when they are not. Useful for
/// [AnimatedSwitcher.duration] and similar imperative APIs.
Duration animDuration(BuildContext context, Duration d) =>
    animationsEnabled(context) ? d : Duration.zero;
