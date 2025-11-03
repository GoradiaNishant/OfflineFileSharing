import 'dart:convert';
import 'dart:math';

import '../core/models/file_transfer_session.dart';

/// Service for handling QR code generation, parsing, and security token management
class QRCodeService {
  static const String _currentVersion = '1.0';
  static const int _tokenLength = 32;
  static const String _tokenChars =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

  /// Generates QR code data string from a FileTransferSession
  ///
  /// Returns a JSON-encoded string containing session information
  /// for QR code generation and scanning
  String generateQRData(FileTransferSession session) {
    if (!session.isValid()) {
      throw ArgumentError('Invalid session provided for QR generation');
    }

    final qrData = {
      'version': _currentVersion,
      'ip': session.ipAddress,
      'port': session.port,
      'token': session.securityToken,
      'fileName': session.fileName,
      'fileSize': session.fileSize,
      'sessionId': session.sessionId,
    };

    return jsonEncode(qrData);
  }

  /// Parses QR code data string and extracts session information
  ///
  /// Throws [FormatException] if the QR data is malformed or invalid
  /// Returns a [FileTransferSession] with connection details
  FileTransferSession parseQRData(String qrDataString) {
    if (qrDataString.isEmpty) {
      throw const FormatException('QR data string cannot be empty');
    }

    try {
      final Map<String, dynamic> qrData = jsonDecode(qrDataString);

      // Validate version compatibility
      _validateVersion(qrData);

      // Validate required fields
      _validateRequiredFields(qrData);

      // Validate data types and ranges
      _validateDataTypes(qrData);

      return FileTransferSession(
        sessionId: qrData['sessionId'] as String,
        filePath: '', // Not included in QR data for security
        fileName: qrData['fileName'] as String,
        fileSize: qrData['fileSize'] as int,
        ipAddress: qrData['ip'] as String,
        port: qrData['port'] as int,
        securityToken: qrData['token'] as String,
        createdAt: DateTime.now(),
      );
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('Failed to parse QR code data: ${e.toString()}');
    }
  }

  /// Generates a cryptographically secure random security token
  ///
  /// Returns a 32-character alphanumeric string suitable for authentication
  String generateSecurityToken() {
    final random = Random.secure();
    return List.generate(
      _tokenLength,
      (index) => _tokenChars[random.nextInt(_tokenChars.length)],
    ).join();
  }

  /// Validates that the security token meets security requirements
  ///
  /// Returns true if the token is valid, false otherwise
  bool validateSecurityToken(String token) {
    if (token.isEmpty) return false;
    if (token.length < 16) return false;

    // Check that token contains only allowed characters
    final allowedChars = RegExp(r'^[a-zA-Z0-9]+$');
    if (!allowedChars.hasMatch(token)) return false;

    return true;
  }

  /// Validates version compatibility
  void _validateVersion(Map<String, dynamic> qrData) {
    if (!qrData.containsKey('version')) {
      throw const FormatException('Missing version field in QR data');
    }

    final version = qrData['version'];
    if (version != _currentVersion) {
      throw FormatException(
        'Unsupported QR data version: $version. Expected: $_currentVersion',
      );
    }
  }

  /// Validates that all required fields are present
  void _validateRequiredFields(Map<String, dynamic> qrData) {
    const requiredFields = [
      'ip',
      'port',
      'token',
      'fileName',
      'fileSize',
      'sessionId',
    ];

    for (final field in requiredFields) {
      if (!qrData.containsKey(field) || qrData[field] == null) {
        throw FormatException('Missing required field: $field');
      }
    }
  }

  /// Validates data types and value ranges
  void _validateDataTypes(Map<String, dynamic> qrData) {
    // Validate IP address format
    final ip = qrData['ip'];
    if (ip is! String || ip.isEmpty) {
      throw const FormatException('Invalid IP address format');
    }

    // Basic IP address format validation
    final ipPattern = RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$');
    if (!ipPattern.hasMatch(ip)) {
      throw const FormatException('Invalid IP address format');
    }

    // Validate port number
    final port = qrData['port'];
    if (port is! int || port <= 0 || port > 65535) {
      throw const FormatException('Invalid port number');
    }

    // Validate security token
    final token = qrData['token'];
    if (token is! String || !validateSecurityToken(token)) {
      throw const FormatException('Invalid security token');
    }

    // Validate file name
    final fileName = qrData['fileName'];
    if (fileName is! String || fileName.isEmpty) {
      throw const FormatException('Invalid file name');
    }

    // Validate file size
    final fileSize = qrData['fileSize'];
    if (fileSize is! int || fileSize < 0) {
      throw const FormatException('Invalid file size');
    }

    // Validate session ID
    final sessionId = qrData['sessionId'];
    if (sessionId is! String || sessionId.isEmpty) {
      throw const FormatException('Invalid session ID');
    }
  }
}
