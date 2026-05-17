import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/env.dart';

/// Single shared Dio instance configured for the Groq OpenAI-compatible API.
/// Shared via [groqClientProvider] so all API classes use the same connection pool.
class GroqClient {
  GroqClient._() : _dio = _build();

  final Dio _dio;

  /// Exposes the configured [Dio] instance to API classes.
  Dio get dio => _dio;

  // ── Factory ───────────────────────────────────────────────────────────────

  static Dio _build() {
    final dio = Dio(
      BaseOptions(
        baseUrl: Env.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 120), // transcription can be slow
        sendTimeout:    const Duration(seconds: 120),
        headers: {
          'Authorization': 'Bearer ${Env.groqApiKey}',
          'Accept': 'application/json',
        },
      ),
    );
    dio.interceptors.add(_RetryInterceptor(dio));
    return dio;
  }
}

// ── Retry interceptor ─────────────────────────────────────────────────────────

class _RetryInterceptor extends Interceptor {
  _RetryInterceptor(this._dio);

  final Dio _dio;

  static const _maxRetries = 3;
  // Exponential back-off delays in ms (architecture §8 risk note).
  static const _delays = [500, 1000, 2000];

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Never retry cancelled requests.
    if (err.type == DioExceptionType.cancel) return handler.next(err);

    final status  = err.response?.statusCode;
    final attempt = (err.requestOptions.extra['_attempt'] as int?) ?? 0;

    final shouldRetry =
        (status == 429 || (status != null && status >= 500)) &&
        attempt < _maxRetries;

    if (!shouldRetry) return handler.next(err);

    // Honour Retry-After on 429, else use the exponential schedule.
    var delayMs = _delays[attempt];
    if (status == 429) {
      final retryAfter = err.response?.headers.value('retry-after');
      if (retryAfter != null) {
        delayMs = ((int.tryParse(retryAfter) ?? 1) * 1000).clamp(500, 30000);
      }
    }

    await Future<void>.delayed(Duration(milliseconds: delayMs));

    // Re-issue the request with an incremented attempt counter.
    final opts = err.requestOptions
      ..extra['_attempt'] = attempt + 1;

    try {
      final response = await _dio.fetch<dynamic>(opts);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final groqClientProvider = Provider<GroqClient>((_) => GroqClient._());
