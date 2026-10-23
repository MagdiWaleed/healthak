import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import 'transitions.dart';

/// The imperative counterpart to [AppPages]' named-route transition setup.
///
/// Detail/editor pages are pushed from cards and sheets, so leaving these on
/// GetX's default transition made the app switch motion vocabulary depending
/// on how a route was reached. This keeps route ownership unchanged while
/// giving both paths the same fade-through-scale choreography.
Future<T?> pushHealthak<T>(Widget Function() page) {
  final navigator = Get.key.currentState;
  if (navigator == null) return Future<T?>.value();
  return navigator.push<T>(
    GetPageRoute<T>(
      page: page,
      customTransition: HealthakTransition(),
      transitionDuration: const Duration(milliseconds: 270),
    ),
  );
}
