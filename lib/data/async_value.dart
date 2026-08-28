/// A small, exhaustive representation of asynchronous UI state.
///
/// Repositories expose streams and futures; controllers translate them to this
/// type so widgets cannot accidentally treat an error as an empty result.
sealed class AsyncValue<T> {
  const AsyncValue();

  R when<R>({
    required R Function() loading,
    required R Function(T value) data,
    required R Function(Object error, StackTrace? stackTrace) onError,
  }) =>
      switch (this) {
        Loading<T>() => loading(),
        Data<T>(:final value) => data(value),
        Error<T>(:final error, :final stackTrace) => onError(error, stackTrace),
      };
}

final class Loading<T> extends AsyncValue<T> {
  const Loading();
}

final class Data<T> extends AsyncValue<T> {
  final T value;

  const Data(this.value);
}

final class Error<T> extends AsyncValue<T> {
  final Object error;
  final StackTrace? stackTrace;

  const Error(this.error, [this.stackTrace]);
}
