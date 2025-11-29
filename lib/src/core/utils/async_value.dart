enum AsyncStatus { data, loading, error }

/// Lightweight replacement for Riverpod's AsyncValue.
class AsyncValue<T> {
  const AsyncValue._({
    required this.status,
    this.value,
    this.error,
    this.stackTrace,
  });

  const AsyncValue.data(T value)
      : this._(
          status: AsyncStatus.data,
          value: value,
        );

  const AsyncValue.loading() : this._(status: AsyncStatus.loading);

  const AsyncValue.error(Object error, [StackTrace? stackTrace])
      : this._(
          status: AsyncStatus.error,
          error: error,
          stackTrace: stackTrace,
        );

  final AsyncStatus status;
  final T? value;
  final Object? error;
  final StackTrace? stackTrace;

  bool get isLoading => status == AsyncStatus.loading;
  bool get hasError => status == AsyncStatus.error;

  T? get valueOrNull => value;

  R when<R>({
    required R Function(T data) data,
    required R Function() loading,
    required R Function(Object error, StackTrace? stackTrace) error,
  }) {
    switch (status) {
      case AsyncStatus.data:
        return data(value as T);
      case AsyncStatus.loading:
        return loading();
      case AsyncStatus.error:
        return error(this.error!, stackTrace);
    }
  }

  R maybeWhen<R>({
    R Function(T data)? data,
    R Function()? loading,
    R Function(Object error, StackTrace? stackTrace)? error,
    required R Function() orElse,
  }) {
    switch (status) {
      case AsyncStatus.data:
        if (data != null) return data(value as T);
        break;
      case AsyncStatus.loading:
        if (loading != null) return loading();
        break;
      case AsyncStatus.error:
        if (error != null) return error(this.error!, stackTrace);
        break;
    }
    return orElse();
  }
}

class AsyncLoading<T> extends AsyncValue<T> {
  const AsyncLoading() : super.loading();
}
