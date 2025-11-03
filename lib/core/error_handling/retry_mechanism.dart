import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'app_error.dart';

/// Retry mechanism with exponential backoff and jitter
class RetryMechanism {
  /// Executes an operation with retry logic
  static Future<T> execute<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
    Duration maxDelay = const Duration(seconds: 30),
    double backoffMultiplier = 2.0,
    bool useJitter = true,
    bool Function(dynamic error)? shouldRetry,
    void Function(int attempt, dynamic error)? onRetry,
  }) async {
    int attempts = 0;
    Duration currentDelay = initialDelay;
    dynamic lastError;

    while (attempts < maxRetries) {
      try {
        attempts++;

        if (kDebugMode && attempts > 1) {
          print('Retry attempt $attempts/$maxRetries');
        }

        return await operation();
      } catch (error) {
        lastError = error;

        // Check if we should retry this error
        final canRetry = shouldRetry?.call(error) ?? _defaultShouldRetry(error);

        if (!canRetry || attempts >= maxRetries) {
          rethrow;
        }

        // Call retry callback
        onRetry?.call(attempts, error);

        // Calculate delay with exponential backoff
        if (attempts < maxRetries) {
          final delay = _calculateDelay(
            currentDelay,
            maxDelay,
            backoffMultiplier,
            useJitter,
          );

          if (kDebugMode) {
            print('Waiting ${delay.inMilliseconds}ms before retry...');
          }

          await Future.delayed(delay);
          currentDelay = Duration(
            milliseconds: (currentDelay.inMilliseconds * backoffMultiplier)
                .round(),
          );
        }
      }
    }

    // This should never be reached, but just in case
    throw lastError;
  }

  /// Default retry logic based on error type
  static bool _defaultShouldRetry(dynamic error) {
    if (error is AppError) {
      return error.isRetryable;
    }

    // Network errors are generally retryable
    if (error is SocketException ||
        error is HttpException ||
        error is TimeoutException) {
      return true;
    }

    // File system errors are generally not retryable
    if (error is FileSystemException) {
      return false;
    }

    // State errors might be retryable depending on the message
    if (error is StateError) {
      final message = error.message.toLowerCase();
      return message.contains('port') ||
          message.contains('network') ||
          message.contains('connection');
    }

    // Format errors (QR parsing) might be retryable
    if (error is FormatException) {
      return true;
    }

    // Default to not retryable for unknown errors
    return false;
  }

  /// Calculates delay with exponential backoff and optional jitter
  static Duration _calculateDelay(
    Duration currentDelay,
    Duration maxDelay,
    double backoffMultiplier,
    bool useJitter,
  ) {
    var delayMs = currentDelay.inMilliseconds;

    if (useJitter) {
      // Add jitter to prevent thundering herd
      final jitter = Random().nextDouble() * 0.1; // 10% jitter
      delayMs = (delayMs * (1 + jitter)).round();
    }

    // Cap at max delay
    delayMs = min(delayMs, maxDelay.inMilliseconds);

    return Duration(milliseconds: delayMs);
  }
}

/// Retry configuration for different operation types
class RetryConfig {
  final int maxRetries;
  final Duration initialDelay;
  final Duration maxDelay;
  final double backoffMultiplier;
  final bool useJitter;

  const RetryConfig({
    this.maxRetries = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.backoffMultiplier = 2.0,
    this.useJitter = true,
  });

  /// Configuration for network operations
  static const network = RetryConfig(
    maxRetries: 3,
    initialDelay: Duration(seconds: 2),
    maxDelay: Duration(seconds: 15),
    backoffMultiplier: 2.0,
    useJitter: true,
  );

  /// Configuration for file operations
  static const fileSystem = RetryConfig(
    maxRetries: 2,
    initialDelay: Duration(seconds: 1),
    maxDelay: Duration(seconds: 5),
    backoffMultiplier: 1.5,
    useJitter: false,
  );

  /// Configuration for QR code operations
  static const qrCode = RetryConfig(
    maxRetries: 5,
    initialDelay: Duration(milliseconds: 500),
    maxDelay: Duration(seconds: 3),
    backoffMultiplier: 1.5,
    useJitter: true,
  );

  /// Configuration for server operations
  static const server = RetryConfig(
    maxRetries: 3,
    initialDelay: Duration(seconds: 1),
    maxDelay: Duration(seconds: 10),
    backoffMultiplier: 2.0,
    useJitter: true,
  );
}

/// Extension to make retry easier to use
extension RetryExtension<T> on Future<T> {
  /// Adds retry logic to any Future
  Future<T> withRetry({
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
    Duration maxDelay = const Duration(seconds: 30),
    double backoffMultiplier = 2.0,
    bool useJitter = true,
    bool Function(dynamic error)? shouldRetry,
    void Function(int attempt, dynamic error)? onRetry,
  }) {
    return RetryMechanism.execute(
      () => this,
      maxRetries: maxRetries,
      initialDelay: initialDelay,
      maxDelay: maxDelay,
      backoffMultiplier: backoffMultiplier,
      useJitter: useJitter,
      shouldRetry: shouldRetry,
      onRetry: onRetry,
    );
  }

  /// Adds retry with predefined configuration
  Future<T> withRetryConfig(RetryConfig config) {
    return RetryMechanism.execute(
      () => this,
      maxRetries: config.maxRetries,
      initialDelay: config.initialDelay,
      maxDelay: config.maxDelay,
      backoffMultiplier: config.backoffMultiplier,
      useJitter: config.useJitter,
    );
  }
}
