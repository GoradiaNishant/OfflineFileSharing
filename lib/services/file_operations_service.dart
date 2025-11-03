import 'dart:io';
import 'package:flutter/services.dart';

/// Service for native file operations like opening folders and files
class FileOperationsService {
  static const MethodChannel _channel = MethodChannel(
    'com.example.offline_file_sharing/file_operations',
  );

  /// Opens the folder containing the specified file or folder path
  static Future<bool> openFolder(String path) async {
    try {
      final result = await _channel.invokeMethod('openFolder', {
        'folderPath': path,
      });
      return result as bool? ?? false;
    } on PlatformException catch (e) {
      print('Error opening folder: ${e.message}');
      return false;
    }
  }

  /// Opens the specified file with the default system app
  static Future<bool> openFile(String filePath) async {
    try {
      final result = await _channel.invokeMethod('openFile', {
        'filePath': filePath,
      });
      return result as bool? ?? false;
    } on PlatformException catch (e) {
      print('Error opening file: ${e.message}');
      return false;
    }
  }

  /// Shares the specified file using the system share dialog
  static Future<bool> shareFile(String filePath) async {
    try {
      final result = await _channel.invokeMethod('shareFile', {
        'filePath': filePath,
      });
      return result as bool? ?? false;
    } on PlatformException catch (e) {
      print('Error sharing file: ${e.message}');
      return false;
    }
  }

  /// Opens the folder where downloaded files are saved
  static Future<bool> openDownloadsFolder() async {
    try {
      // Get the typical downloads path
      final downloadsPath = Platform.isAndroid
          ? '/storage/emulated/0/Download/OfflineSharedData'
          : '/Users/${Platform.environment['USER']}/Downloads/OfflineSharedData';

      return await openFolder(downloadsPath);
    } catch (e) {
      print('Error opening downloads folder: $e');
      return false;
    }
  }

  /// Gets a user-friendly name for the folder containing the file
  static String getFolderDisplayName(String filePath) {
    try {
      final file = File(filePath);
      final parentDir = file.parent;
      final folderName = parentDir.path.split('/').last;

      // Return user-friendly names for common folders
      switch (folderName.toLowerCase()) {
        case 'download':
        case 'downloads':
          return 'Downloads';
        case 'documents':
          return 'Documents';
        case 'pictures':
          return 'Pictures';
        case 'music':
          return 'Music';
        case 'videos':
          return 'Videos';
        default:
          return folderName.isNotEmpty ? folderName : 'Files';
      }
    } catch (e) {
      return 'Files';
    }
  }

  /// Checks if the file exists at the given path
  static Future<bool> fileExists(String filePath) async {
    try {
      final file = File(filePath);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  /// Gets file size in a human-readable format
  static Future<String> getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final bytes = await file.length();
        return _formatBytes(bytes);
      }
      return 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }

  /// Formats bytes into human-readable string
  static String _formatBytes(int bytes) {
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
}
