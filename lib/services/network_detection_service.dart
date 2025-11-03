import 'dart:io';
import 'package:flutter/foundation.dart';
import '../core/utils/network_utils.dart';
import 'hotspot_service.dart';

/// Service for detecting network connectivity and suggesting offline solutions
class NetworkDetectionService {
  /// Checks the current network status and provides recommendations
  static Future<NetworkStatus> checkNetworkStatus() async {
    try {
      // Check if connected to Wi-Fi
      final isWiFiConnected = await NetworkUtils.isConnectedToWiFi();

      if (isWiFiConnected) {
        // Check if we can get a local IP address
        final localIP = await NetworkUtils.getLocalIPAddress();
        if (localIP != null) {
          return NetworkStatus(
            isConnected: true,
            connectionType: NetworkConnectionType.wifi,
            localIP: localIP,
            canShare: true,
            recommendation: 'Connected to Wi-Fi. Ready to share files!',
          );
        }
      }

      // Check if hotspot is active
      final isHotspotActive = await HotspotService.isHotspotActive();
      if (isHotspotActive) {
        final hotspotIP = await HotspotService.getHotspotIP();
        return NetworkStatus(
          isConnected: true,
          connectionType: NetworkConnectionType.hotspot,
          localIP: hotspotIP,
          canShare: true,
          recommendation:
              'Hotspot is active. Other devices can connect to share files.',
        );
      }

      // No network connection - suggest solutions
      return NetworkStatus(
        isConnected: false,
        connectionType: NetworkConnectionType.none,
        localIP: null,
        canShare: false,
        recommendation: _getOfflineRecommendation(),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error checking network status: $e');
      }

      return NetworkStatus(
        isConnected: false,
        connectionType: NetworkConnectionType.unknown,
        localIP: null,
        canShare: false,
        recommendation:
            'Unable to detect network status. Try connecting to Wi-Fi or creating a hotspot.',
      );
    }
  }

  /// Gets recommendations for offline file sharing
  static String _getOfflineRecommendation() {
    if (Platform.isAndroid) {
      return '''
No Wi-Fi connection detected.

Options for offline sharing:
1. Create a Wi-Fi hotspot (recommended)
2. Connect both devices to the same Wi-Fi network
3. Use mobile hotspot from one device

Tap "Setup Offline Sharing" for guidance.
''';
    } else if (Platform.isIOS) {
      return '''
No Wi-Fi connection detected.

Options for offline sharing:
1. Enable Personal Hotspot (Settings > Personal Hotspot)
2. Connect both devices to the same Wi-Fi network
3. Use AirDrop for nearby devices (iOS only)

Tap "Setup Offline Sharing" for guidance.
''';
    } else {
      return '''
No network connection detected.

Please connect both devices to the same Wi-Fi network or create a mobile hotspot.
''';
    }
  }

  /// Checks if the current setup allows for file sharing
  static Future<bool> canShareFiles() async {
    final status = await checkNetworkStatus();
    return status.canShare;
  }

  /// Gets the best IP address for file sharing
  static Future<String?> getBestSharingIP() async {
    final status = await checkNetworkStatus();
    return status.localIP;
  }

  /// Provides step-by-step guidance for offline setup
  static Future<List<OfflineSetupStep>> getOfflineSetupSteps() async {
    final steps = <OfflineSetupStep>[];

    if (Platform.isAndroid) {
      final canCreateHotspot = await HotspotService.canCreateHotspot();

      if (canCreateHotspot) {
        steps.addAll([
          OfflineSetupStep(
            title: 'Create Wi-Fi Hotspot',
            description:
                'Enable hotspot on this device to allow other devices to connect',
            action: OfflineSetupAction.createHotspot,
            isRecommended: true,
          ),
          OfflineSetupStep(
            title: 'Share Network Details',
            description:
                'Share the hotspot name and password with the receiving device',
            action: OfflineSetupAction.shareCredentials,
            isRecommended: true,
          ),
          OfflineSetupStep(
            title: 'Wait for Connection',
            description:
                'Wait for the receiving device to connect to your hotspot',
            action: OfflineSetupAction.waitForConnection,
            isRecommended: true,
          ),
        ]);
      } else {
        steps.add(
          OfflineSetupStep(
            title: 'Manual Hotspot Setup',
            description: 'Go to Settings > Hotspot & Tethering > Wi-Fi Hotspot',
            action: OfflineSetupAction.manualSetup,
            isRecommended: true,
          ),
        );
      }
    } else if (Platform.isIOS) {
      steps.addAll([
        OfflineSetupStep(
          title: 'Enable Personal Hotspot',
          description:
              'Go to Settings > Personal Hotspot > Allow Others to Join',
          action: OfflineSetupAction.manualSetup,
          isRecommended: true,
        ),
        OfflineSetupStep(
          title: 'Share Network Details',
          description:
              'Share your device name and the Wi-Fi password shown in settings',
          action: OfflineSetupAction.shareCredentials,
          isRecommended: true,
        ),
      ]);
    }

    // Alternative options
    steps.addAll([
      OfflineSetupStep(
        title: 'Connect to Same Wi-Fi',
        description: 'Both devices connect to an existing Wi-Fi network',
        action: OfflineSetupAction.connectWiFi,
        isRecommended: false,
      ),
      OfflineSetupStep(
        title: 'Use Mobile Data Hotspot',
        description: 'Use mobile data to create a hotspot (may use data)',
        action: OfflineSetupAction.mobileHotspot,
        isRecommended: false,
      ),
    ]);

    return steps;
  }

  /// Monitors network changes and notifies when sharing becomes possible
  static Stream<NetworkStatus> monitorNetworkChanges() async* {
    while (true) {
      yield await checkNetworkStatus();
      await Future.delayed(const Duration(seconds: 5));
    }
  }
}

/// Represents the current network status
class NetworkStatus {
  final bool isConnected;
  final NetworkConnectionType connectionType;
  final String? localIP;
  final bool canShare;
  final String recommendation;

  const NetworkStatus({
    required this.isConnected,
    required this.connectionType,
    required this.localIP,
    required this.canShare,
    required this.recommendation,
  });

  @override
  String toString() {
    return 'NetworkStatus(connected: $isConnected, type: $connectionType, ip: $localIP, canShare: $canShare)';
  }
}

/// Types of network connections
enum NetworkConnectionType { wifi, hotspot, mobile, none, unknown }

/// Represents a step in the offline setup process
class OfflineSetupStep {
  final String title;
  final String description;
  final OfflineSetupAction action;
  final bool isRecommended;

  const OfflineSetupStep({
    required this.title,
    required this.description,
    required this.action,
    this.isRecommended = false,
  });
}

/// Actions that can be taken for offline setup
enum OfflineSetupAction {
  createHotspot,
  shareCredentials,
  waitForConnection,
  manualSetup,
  connectWiFi,
  mobileHotspot,
}
