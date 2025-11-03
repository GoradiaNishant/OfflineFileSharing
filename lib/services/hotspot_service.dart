import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Service for managing Wi-Fi hotspot functionality for offline file sharing
class HotspotService {
  static const MethodChannel _channel = MethodChannel(
    'com.example.offline_file_sharing/hotspot',
  );

  /// Checks if the device can create a Wi-Fi hotspot
  static Future<bool> canCreateHotspot() async {
    if (!Platform.isAndroid) {
      return false; // Currently only Android supports programmatic hotspot
    }

    try {
      final result = await _channel.invokeMethod('canCreateHotspot');
      return result as bool? ?? false;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Error checking hotspot capability: ${e.message}');
      }
      return false;
    }
  }

  /// Creates a Wi-Fi hotspot with the specified name and password
  /// If it fails, it will redirect to system settings
  static Future<bool> createHotspot({
    required String networkName,
    required String password,
  }) async {
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      // For desktop platforms, always redirect to system settings
      await openHotspotSettings();
      return false;
    } else if (!Platform.isAndroid) {
      // For iOS, always redirect to settings
      await openHotspotSettings();
      return false;
    }

    try {
      final result = await _channel.invokeMethod('createHotspot', {
        'networkName': networkName,
        'password': password,
      });
      return result as bool? ?? false;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Error creating hotspot: ${e.message}');
      }
      // If programmatic creation fails, open settings
      await openHotspotSettings();
      return false;
    }
  }

  /// Opens WiFi settings
  static Future<bool> openWiFiSettings() async {
    try {
      final result = await _channel.invokeMethod('openWiFiSettings');
      return result as bool? ?? false;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Error opening WiFi settings: ${e.message}');
      }
      return false;
    }
  }

  /// Opens hotspot settings
  static Future<bool> openHotspotSettings() async {
    try {
      final result = await _channel.invokeMethod('openHotspotSettings');
      return result as bool? ?? false;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Error opening hotspot settings: ${e.message}');
      }
      return false;
    }
  }

  /// Stops the Wi-Fi hotspot
  static Future<bool> stopHotspot() async {
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      // For desktop platforms, redirect to system settings
      await openHotspotSettings();
      return false;
    } else if (!Platform.isAndroid) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod('stopHotspot');
      return result as bool? ?? false;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Error stopping hotspot: ${e.message}');
      }
      return false;
    }
  }

  /// Checks if hotspot is currently active
  static Future<bool> isHotspotActive() async {
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      // Desktop platforms don't support programmatic hotspot detection
      return false;
    } else if (!Platform.isAndroid) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod('isHotspotActive');
      return result as bool? ?? false;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Error checking hotspot status: ${e.message}');
      }
      return false;
    }
  }

  /// Gets the hotspot configuration (name, password, IP)
  static Future<Map<String, String>?> getHotspotInfo() async {
    if (!Platform.isAndroid) {
      return null;
    }

    try {
      final result = await _channel.invokeMethod('getHotspotInfo');
      if (result != null) {
        return Map<String, String>.from(result as Map);
      }
      return null;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Error getting hotspot info: ${e.message}');
      }
      return null;
    }
  }

  /// Generates a random network name for the hotspot
  static String generateNetworkName() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'FileShare_${timestamp.toString().substring(8)}';
  }

  /// Generates a random password for the hotspot
  static String generatePassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    var password = '';

    for (int i = 0; i < 8; i++) {
      password += chars[(random + i) % chars.length];
    }

    return password;
  }

  /// Gets instructions for manual hotspot setup on different platforms
  static String getManualHotspotInstructions() {
    if (Platform.isIOS) {
      return '''
To share files without Wi-Fi on iOS:

1. Go to Settings > Personal Hotspot
2. Turn on "Allow Others to Join"
3. Note the Wi-Fi password shown
4. Share the network name and password with the receiving device
5. The receiving device should connect to your hotspot
6. Return to the app and start sharing

Network Name: Your iPhone's name
Password: Shown in Personal Hotspot settings
''';
    } else if (Platform.isMacOS) {
      return '''
To share files without Wi-Fi on macOS:

1. Go to System Preferences > Sharing
2. Select "Internet Sharing" from the service list
3. Choose "Wi-Fi" from "To computers using"
4. Set network name and password in Wi-Fi Options
5. Check the "Internet Sharing" checkbox to enable
6. Share the credentials with the receiving device
7. Return to the app and start sharing
''';
    } else if (Platform.isWindows) {
      return '''
To share files without Wi-Fi on Windows:

1. Go to Settings > Network & Internet > Mobile hotspot
2. Turn on "Share my Internet connection with other devices"
3. Click "Edit" to set network name and password
4. Share the credentials with the receiving device
5. The receiving device should connect to your hotspot
6. Return to the app and start sharing

Alternative: Use Command Prompt with netsh commands
''';
    } else if (Platform.isLinux) {
      return '''
To share files without Wi-Fi on Linux:

1. Open Network settings or use NetworkManager
2. Create a new Wi-Fi hotspot connection
3. Set SSID (network name) and password
4. Enable the hotspot connection
5. Share the credentials with the receiving device
6. Return to the app and start sharing

Command line: Use nmcli or create-ap tools
''';
    } else {
      return '''
To share files without Wi-Fi:

1. Enable Wi-Fi hotspot in your device settings
2. Set a network name and password
3. Share the credentials with the receiving device
4. The receiving device should connect to your hotspot
5. Return to the app and start sharing
''';
    }
  }

  /// Checks if devices are on the same network (including hotspot)
  static Future<bool> areDevicesConnected(String targetIP) async {
    try {
      // Try to ping the target IP
      final result = await Process.run('ping', [
        '-c',
        '1',
        '-W',
        '3000',
        targetIP,
      ]);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Gets the current device's IP address when acting as hotspot
  static Future<String?> getHotspotIP() async {
    try {
      // When device is hotspot, it typically uses 192.168.43.1 on Android
      if (Platform.isAndroid) {
        return '192.168.43.1';
      }

      // For iOS, the IP varies but is typically in 172.20.10.x range
      return '172.20.10.1';
    } catch (e) {
      return null;
    }
  }

  /// Provides user-friendly guidance for setting up offline sharing
  static Map<String, String> getOfflineSetupGuidance() {
    return {
      'sender': '''
📡 No Wi-Fi Network Available

To share files without Wi-Fi:

1. Create a hotspot on your device
2. Share the network name and password
3. Wait for the receiver to connect
4. Start sharing your file

Tap "Create Hotspot" to begin.
''',
      'receiver': '''
📡 No Wi-Fi Network Available

To receive files without Wi-Fi:

1. Ask the sender to create a hotspot
2. Connect to their hotspot network
3. Return to this app
4. Scan the QR code to receive files

Make sure you're connected to the sender's hotspot.
''',
    };
  }
}
