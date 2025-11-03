/// Represents the progress of a file transfer operation
class TransferProgress {
  final int bytesTransferred;
  final int totalBytes;
  final DateTime startTime;
  final DateTime? lastUpdateTime;

  const TransferProgress({
    required this.bytesTransferred,
    required this.totalBytes,
    required this.startTime,
    this.lastUpdateTime,
  });

  /// Returns the transfer completion percentage (0.0 to 100.0)
  double get percentage {
    if (totalBytes <= 0) return 0.0;
    return (bytesTransferred / totalBytes) * 100.0;
  }

  /// Returns true if the transfer is complete
  bool get isComplete => bytesTransferred >= totalBytes && totalBytes > 0;

  /// Returns true if the transfer has started
  bool get hasStarted => bytesTransferred > 0;

  /// Calculates transfer speed in bytes per second
  double get speedBytesPerSecond {
    final currentTime = lastUpdateTime ?? DateTime.now();
    final elapsedSeconds =
        currentTime.difference(startTime).inMilliseconds / 1000.0;

    if (elapsedSeconds <= 0) return 0.0;
    return bytesTransferred / elapsedSeconds;
  }

  /// Returns estimated time remaining for transfer completion
  Duration get estimatedTimeRemaining {
    if (isComplete || speedBytesPerSecond <= 0) {
      return Duration.zero;
    }

    final remainingBytes = totalBytes - bytesTransferred;
    final remainingSeconds = remainingBytes / speedBytesPerSecond;
    return Duration(seconds: remainingSeconds.round());
  }

  /// Returns formatted speed string (e.g., "1.5 MB/s", "256 KB/s")
  String get formattedSpeed {
    final speed = speedBytesPerSecond;

    if (speed >= 1024 * 1024) {
      return '${(speed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    } else if (speed >= 1024) {
      return '${(speed / 1024).toStringAsFixed(1)} KB/s';
    } else {
      return '${speed.toStringAsFixed(0)} B/s';
    }
  }

  /// Returns formatted ETA string (e.g., "2m 30s", "45s", "Complete")
  String get formattedETA {
    if (isComplete) return 'Complete';

    final eta = estimatedTimeRemaining;
    if (eta == Duration.zero) return 'Calculating...';

    final hours = eta.inHours;
    final minutes = eta.inMinutes % 60;
    final seconds = eta.inSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  /// Returns formatted file size string (e.g., "1.5 MB", "256 KB")
  String get formattedTotalSize {
    return _formatBytes(totalBytes);
  }

  /// Returns formatted transferred bytes string
  String get formattedTransferredSize {
    return _formatBytes(bytesTransferred);
  }

  /// Returns formatted progress string (e.g., "1.2 MB / 5.0 MB (24%)")
  String get formattedProgress {
    return '${formattedTransferredSize} / ${formattedTotalSize} (${percentage.toStringAsFixed(1)}%)';
  }

  /// Helper method to format bytes into human-readable string
  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    } else if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '$bytes B';
    }
  }

  /// Creates a new TransferProgress with updated values
  TransferProgress copyWith({
    int? bytesTransferred,
    int? totalBytes,
    DateTime? startTime,
    DateTime? lastUpdateTime,
  }) {
    return TransferProgress(
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      totalBytes: totalBytes ?? this.totalBytes,
      startTime: startTime ?? this.startTime,
      lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
    );
  }

  /// Creates a TransferProgress for the start of a transfer
  static TransferProgress start(int totalBytes) {
    final now = DateTime.now();
    return TransferProgress(
      bytesTransferred: 0,
      totalBytes: totalBytes,
      startTime: now,
      lastUpdateTime: now,
    );
  }

  /// Creates a TransferProgress with updated bytes transferred
  TransferProgress updateProgress(int newBytesTransferred) {
    return copyWith(
      bytesTransferred: newBytesTransferred,
      lastUpdateTime: DateTime.now(),
    );
  }

  /// Creates a completed TransferProgress
  TransferProgress complete() {
    return copyWith(
      bytesTransferred: totalBytes,
      lastUpdateTime: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'TransferProgress(${formattedProgress}, ${formattedSpeed}, ETA: ${formattedETA})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TransferProgress &&
        other.bytesTransferred == bytesTransferred &&
        other.totalBytes == totalBytes &&
        other.startTime == startTime &&
        other.lastUpdateTime == lastUpdateTime;
  }

  @override
  int get hashCode {
    return Object.hash(bytesTransferred, totalBytes, startTime, lastUpdateTime);
  }
}
