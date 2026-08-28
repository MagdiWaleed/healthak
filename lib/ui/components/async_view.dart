import 'package:flutter/material.dart';

import '../../data/async_value.dart';
import 'error_state.dart';

class AsyncView<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;

  const AsyncView(
      {required this.value, required this.builder, super.key, this.onRetry});

  @override
  Widget build(BuildContext context) => value.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        data: builder,
        onError: (error, _) =>
            ErrorState(message: error.toString(), onRetry: onRetry),
      );
}
