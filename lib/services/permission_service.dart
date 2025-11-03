import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

/// Service for managing platform-specific permissions required for file sharing
class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  /// Requests network-related permissions required for HTTP server and client operations
  ///
  /// On Android: Validates INTERNET and ACCESS_WIFI_STATE permissions
  /// On iOS: Handles local network usage permissions through Info.plist
  ///
  /// Returns true if all required network permissions are granted
  Future<bool> requestNetworkPermissions() async {
    try {
      if (Platform.isAndroid) {
        // Android INTERNET and ACCESS_WIFI_STATE are normal permissions
        // granted at install time through AndroidManifest.xml
        return await _validateAndroidNetworkPermissions();
      } else if (Platform.isIOS) {
        // iOS local network permissions are handled through Info.plist
        // NSLocalNetworkUsageDescription and NSBonjourServices must be declared
        return await _validateiOSNetworkPermissions();
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Validates Android network permissions are properly declared
  Future<bool> _validateAndroidNetworkPermissions() async {
    try {
      // For Android, INTERNET and ACCESS_WIFI_STATE are normal permissions
      // that are granted at install time if declared in AndroidManifest.xml
      // Since we can't directly check manifest permissions at runtime,
      // we assume they are granted if the app is installed
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Validates iOS network permissions are properly configured
  Future<bool> _validateiOSNetworkPermissions() async {
    try {
      // iOS local network permissions are handled through Info.plist
      // NSLocalNetworkUsageDescription and NSBonjourServices must be declared
      // The actual permission prompt appears when first accessing local network
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Requests storage permissions required for file operations
  ///
  /// Handles reading files for sending and writing files when receiving
  ///
  /// Returns true if storage permissions are granted
  Future<bool> requestStoragePermissions() async {
    try {
      if (Platform.isAndroid) {
        return await _requestAndroidStoragePermissions();
      } else if (Platform.isIOS) {
        return await _requestiOSStoragePermissions();
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Handles Android storage permission requests with graceful fallback
  Future<bool> _requestAndroidStoragePermissions() async {
    try {
      // For Android 11+ (API 30+), prioritize "All Files Access" permission
      final manageExternalStorageStatus =
          await Permission.manageExternalStorage.status;

      if (manageExternalStorageStatus.isGranted) {
        return true;
      }

      // If "All Files Access" is not granted, request it first
      if (manageExternalStorageStatus.isDenied) {
        final manageStorageResult = await Permission.manageExternalStorage
            .request();
        if (manageStorageResult.isGranted) {
          return true;
        }
      }

      // Fallback to regular storage permissions for older Android versions
      final storageStatus = await Permission.storage.status;

      if (storageStatus.isGranted) {
        return true;
      }

      if (storageStatus.isDenied) {
        final requestResult = await Permission.storage.request();
        return requestResult.isGranted;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Handles iOS storage permissions (handled through document picker)
  Future<bool> _requestiOSStoragePermissions() async {
    try {
      // iOS handles file access through document picker and app sandbox
      // No explicit storage permissions needed for file operations
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Requests camera permissions required for QR code scanning
  ///
  /// Returns true if camera permission is granted
  Future<bool> requestCameraPermissions() async {
    try {
      final status = await Permission.camera.status;

      if (status.isGranted) {
        return true;
      }

      if (status.isDenied) {
        final requestResult = await Permission.camera.request();
        return requestResult.isGranted;
      }

      // Handle permanently denied case
      if (status.isPermanentlyDenied) {
        return false;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Checks if network permissions are currently granted
  Future<bool> hasNetworkPermissions() async {
    try {
      if (Platform.isAndroid) {
        // Network permissions are normal permissions on Android
        return await _validateAndroidNetworkPermissions();
      } else if (Platform.isIOS) {
        // iOS local network permissions are handled at runtime
        return await _validateiOSNetworkPermissions();
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Checks if storage permissions are currently granted
  Future<bool> hasStoragePermissions() async {
    try {
      if (Platform.isAndroid) {
        // Prioritize "All Files Access" permission for Android 11+
        final manageExternalStatus =
            await Permission.manageExternalStorage.status;
        if (manageExternalStatus.isGranted) {
          return true;
        }

        // Fallback to regular storage permission
        final status = await Permission.storage.status;
        return status.isGranted;
      } else if (Platform.isIOS) {
        // iOS handles file access through document picker
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Checks if camera permissions are currently granted
  Future<bool> hasCameraPermissions() async {
    try {
      final status = await Permission.camera.status;
      return status.isGranted;
    } catch (e) {
      return false;
    }
  }

  /// Requests all permissions required for the app to function
  ///
  /// Returns a map indicating which permission categories were granted
  Future<Map<String, bool>> requestAllPermissions() async {
    final results = <String, bool>{};

    results['network'] = await requestNetworkPermissions();
    results['storage'] = await requestStoragePermissions();
    results['camera'] = await requestCameraPermissions();

    return results;
  }

  /// Checks if all required permissions are granted
  Future<bool> hasAllRequiredPermissions() async {
    final networkGranted = await hasNetworkPermissions();
    final storageGranted = await hasStoragePermissions();
    final cameraGranted = await hasCameraPermissions();

    return networkGranted && storageGranted && cameraGranted;
  }

  /// Requests "All Files Access" permission specifically for Android 11+
  Future<bool> requestAllFilesAccessPermission() async {
    if (!Platform.isAndroid) {
      return true; // Not applicable for non-Android platforms
    }

    try {
      final status = await Permission.manageExternalStorage.status;

      if (status.isGranted) {
        return true;
      }

      if (status.isDenied) {
        final result = await Permission.manageExternalStorage.request();
        return result.isGranted;
      }

      // If permanently denied, guide user to settings
      if (status.isPermanentlyDenied) {
        return false;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Checks if "All Files Access" permission is granted
  Future<bool> hasAllFilesAccessPermission() async {
    if (!Platform.isAndroid) {
      return true; // Not applicable for non-Android platforms
    }

    try {
      final status = await Permission.manageExternalStorage.status;
      return status.isGranted;
    } catch (e) {
      return false;
    }
  }

  /// Opens the app settings page for manual permission management
  Future<bool> openAppSettings() async {
    try {
      return await openAppSettings();
    } catch (e) {
      return false;
    }
  }

  /// Handles permission denial gracefully by providing user guidance
  ///
  /// Returns a user-friendly message explaining the permission requirement
  String getPermissionDenialMessage(String permissionType) {
    switch (permissionType.toLowerCase()) {
      case 'network':
        if (Platform.isAndroid) {
          return 'Network access is required to share files between devices. '
              'Please ensure INTERNET and ACCESS_WIFI_STATE permissions are granted in AndroidManifest.xml.';
        } else if (Platform.isIOS) {
          return 'Local network access is required to share files between devices. '
              'Please ensure NSLocalNetworkUsageDescription is configured in Info.plist.';
        }
        return 'Network access is required to share files between devices.';
      case 'storage':
        if (Platform.isAndroid) {
          return 'Storage access is required to read and save files. '
              'Please enable "All files access" permission in Settings > Apps > Offline File Sharing > Permissions > Files and media > Allow access to manage all files.';
        } else if (Platform.isIOS) {
          return 'File access is handled through the document picker. '
              'No additional permissions required.';
        }
        return 'Storage access is required to read and save files.';
      case 'camera':
        return 'Camera access is required to scan QR codes for receiving files. '
            'Please grant camera permission in app settings.';
      default:
        return 'This permission is required for the app to function properly. '
            'Please grant the permission in app settings.';
    }
  }

  /// Checks if a specific permission is permanently denied
  Future<bool> isPermissionPermanentlyDenied(String permissionType) async {
    try {
      switch (permissionType.toLowerCase()) {
        case 'camera':
          final status = await Permission.camera.status;
          return status.isPermanentlyDenied;
        case 'storage':
          if (Platform.isAndroid) {
            final status = await Permission.storage.status;
            final externalStatus =
                await Permission.manageExternalStorage.status;
            return status.isPermanentlyDenied &&
                externalStatus.isPermanentlyDenied;
          }
          return false;
        case 'network':
          // Network permissions are not runtime permissions
          return false;
        default:
          return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Provides platform-specific guidance for permission issues
  Map<String, String> getPlatformSpecificGuidance() {
    if (Platform.isAndroid) {
      return {
        'network':
            'Ensure INTERNET and ACCESS_WIFI_STATE permissions are declared in AndroidManifest.xml',
        'storage':
            'Enable "All files access" in Settings > Apps > Offline File Sharing > Permissions > Files and media > Allow access to manage all files',
        'camera':
            'Grant camera permission in Settings > Apps > Offline File Sharing > Permissions',
      };
    } else if (Platform.isIOS) {
      return {
        'network':
            'Ensure NSLocalNetworkUsageDescription and NSBonjourServices are configured in Info.plist',
        'storage':
            'File access is handled through document picker - no additional setup required',
        'camera':
            'Grant camera permission when prompted or in Settings > Privacy & Security > Camera',
      };
    }

    return {};
  }
}
