import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import '../core/models/file_transfer_session.dart';
import '../core/models/transfer_progress.dart';
import '../core/utils/network_utils.dart';
import '../core/services/platform_optimization_service.dart';

/// Service for managing HTTP file server operations
class FileServerService {
  HttpServer? _server;
  FileTransferSession? _currentSession;
  final StreamController<TransferProgress> _progressController =
      StreamController<TransferProgress>.broadcast();

  /// Stream of transfer progress updates
  Stream<TransferProgress> get progressStream => _progressController.stream;

  /// Current active session, null if no server is running
  FileTransferSession? get currentSession => _currentSession;

  /// Whether the server is currently running
  bool get isRunning => _server != null && _currentSession != null;

  /// Starts the HTTP server for the given file
  Future<FileTransferSession> startServer(File file) async {
    if (isRunning) {
      throw StateError('Server is already running');
    }

    if (!await file.exists()) {
      throw FileSystemException('File does not exist', file.path);
    }

    // Get local IP address
    final ipAddress = await NetworkUtils.getLocalIPAddress();
    if (ipAddress == null) {
      throw StateError('Could not determine local IP address');
    }

    // Find available port
    final port = await NetworkUtils.findAvailablePort();
    if (port == null) {
      throw StateError('No available ports found');
    }

    // Create session
    final session = FileTransferSession(
      sessionId: _generateSessionId(),
      filePath: file.path,
      fileName: file.uri.pathSegments.last,
      fileSize: await file.length(),
      ipAddress: ipAddress,
      port: port,
      securityToken: FileTransferSession.generateSecurityToken(),
      createdAt: DateTime.now(),
    );

    try {
      // Create and start server with platform-specific configuration
      final handler = _createHandler(session, file);
      final platformService = PlatformOptimizationService();
      final config = platformService.getNetworkConfig();

      _server = await shelf_io.serve(
        handler,
        ipAddress,
        port,
        poweredByHeader: null, // Remove server header for security
      );

      // Configure server timeouts based on platform
      _server!.idleTimeout = Duration(
        milliseconds: config['readTimeout'] as int,
      );

      _currentSession = session;

      // Initialize progress tracking
      _progressController.add(TransferProgress.start(session.fileSize));

      return session;
    } catch (e) {
      _server = null;
      _currentSession = null;
      rethrow;
    }
  }

  /// Stops the HTTP server and cleans up resources
  Future<void> stopServer() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }

    _currentSession = null;

    // Send completion progress if there was an active session
    if (_currentSession != null) {
      _progressController.add(
        TransferProgress.start(_currentSession!.fileSize).complete(),
      );
    }
  }

  /// Validates if a session token is valid for the current session
  bool validateToken(String sessionId, String token) {
    if (_currentSession == null) return false;
    if (_currentSession!.sessionId != sessionId) return false;
    if (_currentSession!.securityToken != token) return false;
    if (_currentSession!.isExpired()) return false;
    return true;
  }

  /// Creates the HTTP request handler
  Handler _createHandler(FileTransferSession session, File file) {
    return Pipeline()
        .addMiddleware(_corsMiddleware())
        .addMiddleware(_loggingMiddleware())
        .addHandler((Request request) async {
          // Handle preflight requests
          if (request.method == 'OPTIONS') {
            return Response.ok('', headers: _corsHeaders());
          }

          final path = request.url.path;
          final sessionId = request.url.queryParameters['sessionId'];
          final token = request.url.queryParameters['token'];

          // Health check endpoint
          if (path == 'health') {
            return Response.ok(
              jsonEncode({'status': 'healthy', 'sessionId': session.sessionId}),
              headers: {'Content-Type': 'application/json', ..._corsHeaders()},
            );
          }

          // File info endpoint
          if (path == 'info/${session.sessionId}') {
            if (!validateToken(sessionId ?? '', token ?? '')) {
              return Response.forbidden(
                jsonEncode({'error': 'Invalid or expired token'}),
                headers: {
                  'Content-Type': 'application/json',
                  ..._corsHeaders(),
                },
              );
            }

            final fileInfo = {
              'sessionId': session.sessionId,
              'fileName': session.fileName,
              'fileSize': session.fileSize,
              'contentType': _getContentType(session.fileName),
            };

            return Response.ok(
              jsonEncode(fileInfo),
              headers: {'Content-Type': 'application/json', ..._corsHeaders()},
            );
          }

          // File download endpoint
          if (path == 'file/${session.sessionId}') {
            if (!validateToken(sessionId ?? '', token ?? '')) {
              return Response.forbidden(
                jsonEncode({'error': 'Invalid or expired token'}),
                headers: {
                  'Content-Type': 'application/json',
                  ..._corsHeaders(),
                },
              );
            }

            return _handleFileDownload(request, file, session);
          }

          // Not found
          return Response.notFound(
            jsonEncode({'error': 'Endpoint not found'}),
            headers: {'Content-Type': 'application/json', ..._corsHeaders()},
          );
        });
  }

  /// Handles file download requests with progress tracking
  Future<Response> _handleFileDownload(
    Request request,
    File file,
    FileTransferSession session,
  ) async {
    try {
      final fileStream = file.openRead();
      final contentType = _getContentType(session.fileName);

      // Track progress
      int bytesTransferred = 0;
      final progressStream = fileStream.transform(
        StreamTransformer<List<int>, List<int>>.fromHandlers(
          handleData: (data, sink) {
            bytesTransferred += data.length;
            _progressController.add(
              TransferProgress.start(
                session.fileSize,
              ).updateProgress(bytesTransferred),
            );
            sink.add(data);
          },
          handleDone: (sink) {
            // Mark transfer as complete
            _progressController.add(
              TransferProgress.start(session.fileSize).complete(),
            );

            // Auto-shutdown server after transfer completion
            Timer(const Duration(seconds: 2), () {
              stopServer();
            });

            sink.close();
          },
        ),
      );

      return Response.ok(
        progressStream,
        headers: {
          'Content-Type': contentType,
          'Content-Length': session.fileSize.toString(),
          'Content-Disposition': 'attachment; filename="${session.fileName}"',
          'Accept-Ranges': 'bytes',
          ..._corsHeaders(),
        },
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to serve file: ${e.toString()}'}),
        headers: {'Content-Type': 'application/json', ..._corsHeaders()},
      );
    }
  }

  /// CORS middleware for cross-origin requests
  Middleware _corsMiddleware() {
    return (Handler innerHandler) {
      return (Request request) async {
        final response = await innerHandler(request);
        return response.change(headers: _corsHeaders());
      };
    };
  }

  /// Logging middleware for request tracking
  Middleware _loggingMiddleware() {
    return (Handler innerHandler) {
      return (Request request) async {
        final startTime = DateTime.now();
        final response = await innerHandler(request);
        final duration = DateTime.now().difference(startTime);

        print(
          '${request.method} ${request.requestedUri.path} - '
          '${response.statusCode} (${duration.inMilliseconds}ms)',
        );

        return response;
      };
    };
  }

  /// Returns CORS headers
  Map<String, String> _corsHeaders() {
    return {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      'Access-Control-Max-Age': '86400',
    };
  }

  /// Determines content type based on file extension
  String _getContentType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();

    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'txt':
        return 'text/plain';
      case 'json':
        return 'application/json';
      case 'zip':
        return 'application/zip';
      case 'mp4':
        return 'video/mp4';
      case 'mp3':
        return 'audio/mpeg';
      default:
        return 'application/octet-stream';
    }
  }

  /// Generates a unique session ID
  String _generateSessionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = FileTransferSession.generateSecurityToken().substring(0, 8);
    return 'session_${timestamp}_$random';
  }

  /// Disposes of the service and cleans up resources
  void dispose() {
    stopServer();
    _progressController.close();
  }
}
