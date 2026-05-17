import 'package:dio/dio.dart';

// ── Failure hierarchy ─────────────────────────────────────────────────────────

sealed class Failure {
  const Failure(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// No network connection or request timed out.
final class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Pas de connexion réseau.']);
}

/// The remote API returned a non-2xx status code.
final class ApiFailure extends Failure {
  const ApiFailure({required this.status, required super.message});
  final int status;
}

/// Microphone or notification permission denied.
final class PermissionFailure extends Failure {
  const PermissionFailure([super.message = 'Permission refusée.']);
}

/// Audio file exceeds the API size limit (25 MB after chunking attempts).
final class FileTooLargeFailure extends Failure {
  const FileTooLargeFailure([super.message = 'Fichier audio trop volumineux.']);
}

/// Recording was empty or contained only silence.
final class EmptyAudioFailure extends Failure {
  const EmptyAudioFailure([super.message = 'Enregistrement vide ou silencieux.']);
}

/// The request was cancelled by the user (ProcessingPage back-button).
final class CancelledFailure extends Failure {
  const CancelledFailure([super.message = 'Opération annulée.']);
}

// ── Result<T> ─────────────────────────────────────────────────────────────────

/// Lightweight Either monad — avoids throwing exceptions across layer boundaries.
sealed class Result<T> {
  const Result();

  bool get isOk  => this is Ok<T>;
  bool get isErr => this is Err<T>;

  /// Returns the value or throws the [Failure] as an exception.
  T getOrThrow() => switch (this) {
        Ok(:final value)      => value,
        Err(:final failure)   => throw failure,
      };

  /// Maps the success value without changing error type.
  Result<R> map<R>(R Function(T) f) => switch (this) {
        Ok(:final value)    => Ok(f(value)),
        Err(:final failure) => Err(failure),
      };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);
  final Failure failure;
}

// ── Dio error mapper ──────────────────────────────────────────────────────────

/// Converts a [DioException] into the appropriate typed [Failure].
Failure mapDioError(DioException e) {
  if (e.type == DioExceptionType.cancel) {
    return const CancelledFailure();
  }

  if (e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.sendTimeout ||
      e.type == DioExceptionType.connectionError) {
    return const NetworkFailure();
  }

  final status = e.response?.statusCode;
  if (status != null) {
    final body = e.response?.data;
    final apiMsg = _extractApiMessage(body) ?? e.message ?? 'Erreur API ($status)';
    return ApiFailure(status: status, message: apiMsg);
  }

  return NetworkFailure(e.message ?? 'Erreur réseau inconnue.');
}

String? _extractApiMessage(dynamic body) {
  if (body is Map) {
    // Groq error shape: { "error": { "message": "..." } }
    final error = body['error'];
    if (error is Map) return error['message']?.toString();
    return body['message']?.toString();
  }
  return null;
}
