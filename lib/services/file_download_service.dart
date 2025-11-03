import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import '../core/models/file_transfer_session.dart';
import '../core/models/transfer_progress.dart';
import '../core/services/platform_optimization_service.dart';

/// Service for downloading files from remote HTTP servers
class FileDownloadService {
  HttpClient? _httpClient;
  final StreamController<TransferProgress> _progressController =
      StreamController<TransferProgress>.broadcast();

  /// Stream of download progress updates
  Stream<TransferProgress> get progressStream => _progressController.stream;

  /// Whether a download is currently in progress
  bool get isDownloading => _httpClient != null;

  /// Validates connection to the remote server before download
  Future<bool> validateConnection(String ip, int port, String token) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);

      final uri = Uri.http('$ip:$port', '/health');
      final request = await client.getUrl(uri);
      final response = await request.close();

      await response.drain();
      client.close();

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Downloads file from the given session with progress tracking
  Future<String> downloadFile(
    FileTransferSession session,
    String? customSavePath,
  ) async {
    if (isDownloading) {
      throw StateError('Download already in progress');
    }

    if (!session.isValid()) {
      throw ArgumentError('Invalid or expired session');
    }

    _httpClient = HttpClient();

    // Configure timeouts based on platform
    final platformService = PlatformOptimizationService();
    final config = platformService.getNetworkConfig();

    _httpClient!.connectionTimeout = Duration(
      milliseconds: config['connectionTimeout'] as int,
    );
    _httpClient!.idleTimeout = Duration(
      milliseconds: config['readTimeout'] as int,
    );

    try {
      // Validate connection first
      final isConnected = await validateConnection(
        session.ipAddress,
        session.port,
        session.securityToken,
      );

      if (!isConnected) {
        throw StateError(
          'Cannot connect to server at ${session.ipAddress}:${session.port}',
        );
      }

      // Get file info first
      final fileInfo = await _getFileInfo(session);
      final actualFileSize = fileInfo['fileSize'] as int? ?? session.fileSize;

      // Determine save path
      final savePath = await _determineSavePath(
        customSavePath,
        session.fileName,
      );

      // Start download
      final downloadedPath = await _performDownload(
        session,
        savePath,
        actualFileSize,
      );

      return downloadedPath;
    } finally {
      _httpClient?.close();
      _httpClient = null;
    }
  }

  /// Gets file information from the server
  Future<Map<String, dynamic>> _getFileInfo(FileTransferSession session) async {
    final uri = Uri.http(
      '${session.ipAddress}:${session.port}',
      '/info/${session.sessionId}',
      {'sessionId': session.sessionId, 'token': session.securityToken},
    );

    final request = await _httpClient!.getUrl(uri);
    final response = await request.close();

    if (response.statusCode != 200) {
      throw HttpException(
        'Failed to get file info: HTTP ${response.statusCode}',
        uri: uri,
      );
    }

    final responseBody = await response.transform(utf8.decoder).join();
    return jsonDecode(responseBody) as Map<String, dynamic>;
  }

  /// Performs the actual file download with progress tracking
  Future<String> _performDownload(
    FileTransferSession session,
    String savePath,
    int fileSize,
  ) async {
    final uri = Uri.http(
      '${session.ipAddress}:${session.port}',
      '/file/${session.sessionId}',
      {'sessionId': session.sessionId, 'token': session.securityToken},
    );

    final request = await _httpClient!.getUrl(uri);
    final response = await request.close();

    if (response.statusCode != 200) {
      throw HttpException(
        'Download failed: HTTP ${response.statusCode}',
        uri: uri,
      );
    }

    // Create output file
    final file = File(savePath);
    await file.create(recursive: true);
    final sink = file.openWrite();

    try {
      // Initialize progress tracking
      int bytesDownloaded = 0;
      final progress = TransferProgress.start(fileSize);
      _progressController.add(progress);

      // Download with progress tracking
      await for (final chunk in response) {
        sink.add(chunk);
        bytesDownloaded += chunk.length;

        // Update progress
        final updatedProgress = progress.updateProgress(bytesDownloaded);
        _progressController.add(updatedProgress);
      }

      // Complete progress
      _progressController.add(progress.complete());

      return savePath;
    } finally {
      await sink.close();
    }
  }

  /// Determines the appropriate save path for the downloaded file
  Future<String> _determineSavePath(String? customPath, String fileName) async {
    // Sanitize the filename first
    final sanitizedFileName = _sanitizeFileName(fileName);

    if (customPath != null) {
      // If custom path is provided, ensure the directory exists
      final customFile = File(customPath);
      final customDir = customFile.parent;
      if (!await customDir.exists()) {
        await customDir.create(recursive: true);
      }
      return customPath;
    }

    // Use system Downloads directory for Android
    Directory downloadsDir;

    if (Platform.isAndroid) {
      // Use the system Downloads folder on Android
      downloadsDir = Directory(
        '/storage/emulated/0/Download/OfflineSharedData',
      );

      // Fallback to external storage Downloads if the primary path doesn't exist
      if (!await downloadsDir.exists()) {
        try {
          final externalDir = await getExternalStorageDirectory();
          if (externalDir != null) {
            downloadsDir = Directory(
              '${externalDir.path}/Download/OfflineSharedData',
            );
          } else {
            // Final fallback to app documents directory
            final documentsDir = await getApplicationDocumentsDirectory();
            downloadsDir = Directory(
              '${documentsDir.path}/Downloads/OfflineSharedData',
            );
          }
        } catch (e) {
          // Final fallback to app documents directory
          final documentsDir = await getApplicationDocumentsDirectory();
          downloadsDir = Directory(
            '${documentsDir.path}/Downloads/OfflineSharedData',
          );
        }
      }
    } else {
      // For iOS and other platforms, use app documents directory
      final documentsDir = await getApplicationDocumentsDirectory();
      downloadsDir = Directory(
        '${documentsDir.path}/Downloads/OfflineSharedData',
      );
    }

    // Ensure the downloads directory exists
    if (!await downloadsDir.exists()) {
      try {
        await downloadsDir.create(recursive: true);
      } catch (e) {
        // If we can't create the system Downloads folder, fall back to app directory
        final documentsDir = await getApplicationDocumentsDirectory();
        downloadsDir = Directory(
          '${documentsDir.path}/Downloads/OfflineSharedData',
        );
        await downloadsDir.create(recursive: true);
      }
    }

    // Handle duplicate filenames
    String basePath = '${downloadsDir.path}/$sanitizedFileName';
    String finalPath = basePath;
    int counter = 1;

    while (await File(finalPath).exists()) {
      final lastDotIndex = sanitizedFileName.lastIndexOf('.');
      if (lastDotIndex != -1) {
        final nameWithoutExt = sanitizedFileName.substring(0, lastDotIndex);
        final extension = sanitizedFileName.substring(lastDotIndex);
        finalPath = '${downloadsDir.path}/${nameWithoutExt}_$counter$extension';
      } else {
        finalPath = '${downloadsDir.path}/${sanitizedFileName}_$counter';
      }
      counter++;
    }

    return finalPath;
  }

  /// Cancels the current download if in progress
  Future<void> cancelDownload() async {
    if (_httpClient != null) {
      _httpClient!.close(force: true);
      _httpClient = null;
    }
  }

  /// Checks available storage space before download
  Future<bool> hasEnoughStorage(int requiredBytes) async {
    try {
      // Get available space (this is a simplified check)
      // In a real implementation, you might need platform-specific code
      final availableSpace = await _getAvailableStorageSpace();

      return availableSpace > requiredBytes + (10 * 1024 * 1024); // 10MB buffer
    } catch (e) {
      // If we can't determine space, assume we have enough
      return true;
    }
  }

  /// Gets available storage space (simplified implementation)
  Future<int> _getAvailableStorageSpace() async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final tempFile = File('${documentsDir.path}/.temp_space_check');

      // Try to create a small file to test write permissions
      await tempFile.writeAsBytes([0]);
      await tempFile.delete();

      // Return a large number as we can't easily get actual free space
      // In production, you'd use platform-specific code
      return 1024 * 1024 * 1024; // 1GB assumption
    } catch (e) {
      throw StorageException('Cannot access storage: ${e.toString()}');
    }
  }

  /// Validates file integrity after download (basic size check)
  Future<bool> validateDownloadedFile(String filePath, int expectedSize) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return false;
      }

      final actualSize = await file.length();
      return actualSize == expectedSize;
    } catch (e) {
      return false;
    }
  }

  /// Downloads file with comprehensive error handling and retry logic
  Future<String> downloadFileWithRetry(
    FileTransferSession session, {
    String? customSavePath,
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 2),
  }) async {
    int attempts = 0;
    Exception? lastException;

    while (attempts < maxRetries) {
      try {
        attempts++;

        // Check storage space before download
        if (!await hasEnoughStorage(session.fileSize)) {
          throw StorageException(
            'Insufficient storage space. Need ${_formatBytes(session.fileSize)} bytes.',
          );
        }

        final downloadedPath = await downloadFile(session, customSavePath);

        // Validate downloaded file
        if (!await validateDownloadedFile(downloadedPath, session.fileSize)) {
          throw FileSystemException(
            'Downloaded file validation failed',
            downloadedPath,
          );
        }

        return downloadedPath;
      } on SocketException catch (e) {
        lastException = NetworkException('Network error: ${e.message}');
        if (attempts >= maxRetries) break;
        await Future.delayed(retryDelay);
      } on HttpException catch (e) {
        lastException = NetworkException('HTTP error: ${e.message}');
        if (attempts >= maxRetries) break;
        await Future.delayed(retryDelay);
      } on TimeoutException catch (e) {
        lastException = NetworkException('Connection timeout: ${e.message}');
        if (attempts >= maxRetries) break;
        await Future.delayed(retryDelay);
      } on StorageException {
        // Don't retry storage issues
        rethrow;
      } catch (e) {
        lastException = Exception('Download failed: ${e.toString()}');
        if (attempts >= maxRetries) break;
        await Future.delayed(retryDelay);
      }
    }

    throw lastException ??
        Exception('Download failed after $maxRetries attempts');
  }

  /// Creates a safe filename by removing invalid characters
  String _sanitizeFileName(String fileName) {
    // Remove or replace invalid characters for file systems
    final invalidChars = RegExp(r'[<>:"/\\|?*]');
    String sanitized = fileName.replaceAll(invalidChars, '_');

    // Ensure filename isn't too long (255 chars is common limit)
    if (sanitized.length > 255) {
      final extension = sanitized.contains('.')
          ? sanitized.substring(sanitized.lastIndexOf('.'))
          : '';
      final nameWithoutExt = sanitized.contains('.')
          ? sanitized.substring(0, sanitized.lastIndexOf('.'))
          : sanitized;

      final maxNameLength = 255 - extension.length;
      sanitized = nameWithoutExt.substring(0, maxNameLength) + extension;
    }

    return sanitized;
  }

  /// Formats bytes into human-readable string
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

  /// Disposes of the service and cleans up resources
  void dispose() {
    cancelDownload();
    _progressController.close();
  }
}

/// Custom exception for network-related errors
class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);

  @override
  String toString() => 'NetworkException: $message';
}

/// Custom exception for storage-related errors
class StorageException implements Exception {
  final String message;
  StorageException(this.message);

  @override
  String toString() => 'StorageException: $message';
}
