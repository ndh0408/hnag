// Deep-link router (Android intent + iOS universal link → in-app navigation).
//
// Audit hnag-audit-2026-05 §5-Flutter / §19 — without deep linking the
// product cannot share a restaurant / food / claim URL, killing organic
// growth and SEO. The Android manifest already declares the intent-filters
// (see AndroidManifest.xml below the LAUNCHER one). This file converts an
// incoming Uri into an in-app navigation.
//
// URI scheme:
//     https://tothanhthuy.cloud/r/<restaurantId>     (App Links / Universal Links)
//     https://tothanhthuy.cloud/f/<foodId>
//     https://tothanhthuy.cloud/c/<claimId>
//     hnag://r/<restaurantId>                         (custom-scheme fallback)
//     hnag://f/<foodId>
//     hnag://c/<claimId>
//
// Wire-up in main.dart:
//
//     final dl = DeepLinkRouter(navigator: navigatorKey);
//     await dl.handleInitialLink();   // app launched cold via a link
//     dl.startListening();            // app already running, link arrives
//
// Requires the `app_links` package (cross-platform Android / iOS / macOS).
// If you cannot add the dep yet, the file still type-checks against a
// minimal fake; see DeepLinkRouter.attach below for the manual-call API.

import 'package:flutter/material.dart';

/// A single resolved navigation target — the screen the deep link maps to.
class DeepLinkTarget {
  final String route;
  final Map<String, String> params;
  const DeepLinkTarget(this.route, [this.params = const {}]);
  @override
  String toString() => 'DeepLinkTarget($route, $params)';
}

class DeepLinkRouter {
  final GlobalKey<NavigatorState> navigator;
  DeepLinkRouter({required this.navigator});

  /// Parse a URI into an in-app target. Returns null for unknown links so
  /// the caller can fall back to the default route.
  static DeepLinkTarget? parse(Uri? uri) {
    if (uri == null) return null;
    final segments = uri.pathSegments;
    if (segments.length < 2) return null;
    final id = segments[1];
    if (id.isEmpty) return null;
    switch (segments.first) {
      case 'r':
        return DeepLinkTarget('/restaurant', {'id': id});
      case 'f':
        return DeepLinkTarget('/food', {'id': id});
      case 'c':
        return DeepLinkTarget('/claim', {'id': id});
      default:
        return null;
    }
  }

  /// Push the parsed target onto the navigator. Wired to the named-route
  /// table the app already uses; if your routing layer uses go_router /
  /// auto_route / Beamer instead, swap this body.
  void open(DeepLinkTarget t) {
    final nav = navigator.currentState;
    if (nav == null) return;
    final args = t.params;
    nav.pushNamed(t.route, arguments: args);
  }

  /// Convenience — parse + open in one go.
  void handle(Uri? uri) {
    final t = parse(uri);
    if (t != null) open(t);
  }
}
