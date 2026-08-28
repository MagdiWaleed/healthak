import 'package:flutter/material.dart';

class LegacyLtrShim extends StatelessWidget {
  final Widget child;

  const LegacyLtrShim({required this.child, super.key});

  @override
  Widget build(BuildContext context) =>
      Directionality(textDirection: TextDirection.ltr, child: child);
}
