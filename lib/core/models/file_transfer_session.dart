import 'dart:convert';
import 'dart:math';

/// Represents a file transfer session with connection details and metadata
class FileTransferSession {
  final String sessionId;
  final String filePath;
  final String fileName;
  final int fileSize;
  final String ipAddress;
  final int port;
  final String securityToken;
  final DateTime createdAt;
  final Duration sessionTimeout;

  const FileTransferSession({
    required this.sessionId,
    required this.filePath,
    required this.fileName,
    required this.fileSize,
    required this.ipAddress,
    required this.port,
    required this.securityToken,
    required this.createdAt,
    this.sessionTimeout = const Duration(hours: 1),
  });

  /// Generates QR code data as JSON string containing connection information
  String generateQRData() {
    final qrData = {
      'version': '1.0',
      'ip': ipAddress,
      'port': port,
      'token': securityToken,
      'fileName': fileName,
      'fileSize': fileSize,
      'sessionId': sessionId,
    };
    return jsonEncode(qrData);
  }

  /// Parses QR code data string and creates FileTransferSession instance
  static FileTransferSession parseQRData(String qrDataString) {
    try {
      final Map<String, dynamic> qrData = jsonDecode(qrDataString);

      // Validate required fields
      final requiredFields = [
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
    } catch (e) {
      throw FormatException('Invalid QR code data: ${e.toString()}');
    }
  }

  /// Checks if the session has expired based on creation time and timeout duration
  bool isExpired() {
    return DateTime.now().difference(createdAt) > sessionTimeout;
  }

  /// Validates session by checking expiration and token format
  bool isValid() {
    if (isExpired()) return false;
    if (securityToken.isEmpty || securityToken.length < 16) return false;
    if (sessionId.isEmpty) return false;
    if (ipAddress.isEmpty || port <= 0) return false;
    return true;
  }

  /// Generates a cryptographically secure random token
  static String generateSecurityToken() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(
      32,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
  }

  /// Creates a copy of the session with updated fields
  FileTransferSession copyWith({
    String? sessionId,
    String? filePath,
    String? fileName,
    int? fileSize,
    String? ipAddress,
    int? port,
    String? securityToken,
    DateTime? createdAt,
    Duration? sessionTimeout,
  }) {
    return FileTransferSession(
      sessionId: sessionId ?? this.sessionId,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      securityToken: securityToken ?? this.securityToken,
      createdAt: createdAt ?? this.createdAt,
      sessionTimeout: sessionTimeout ?? this.sessionTimeout,
    );
  }

  @override
  String toString() {
    return 'FileTransferSession(sessionId: $sessionId, fileName: $fileName, '
        'fileSize: $fileSize, ipAddress: $ipAddress, port: $port, '
        'isExpired: ${isExpired()})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FileTransferSession &&
        other.sessionId == sessionId &&
        other.filePath == filePath &&
        other.fileName == fileName &&
        other.fileSize == fileSize &&
        other.ipAddress == ipAddress &&
        other.port == port &&
        other.securityToken == securityToken &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      sessionId,
      filePath,
      fileName,
      fileSize,
      ipAddress,
      port,
      securityToken,
      createdAt,
    );
  }
}
