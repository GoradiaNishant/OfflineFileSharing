import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/network_detection_service.dart';
import '../../services/hotspot_service.dart';

class OfflineSetupScreen extends StatefulWidget {
  const OfflineSetupScreen({super.key});

  @override
  State<OfflineSetupScreen> createState() => _OfflineSetupScreenState();
}

class _OfflineSetupScreenState extends State<OfflineSetupScreen> {
  NetworkStatus? _networkStatus;
  bool _isLoading = true;
  bool _isProcessing = false;
  Timer? _networkTimer;

  @override
  void initState() {
    super.initState();
    _startNetworkMonitoring();
  }

  @override
  void dispose() {
    _networkTimer?.cancel();
    super.dispose();
  }

  void _startNetworkMonitoring() {
    // Initial check
    _checkNetworkStatus();

    // Set up periodic monitoring every 2 seconds (more frequent for setup screen)
    _networkTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        _checkNetworkStatus();
      }
    });
  }

  Future<void> _checkNetworkStatus() async {
    // Only show loading on initial check
    if (_networkStatus == null) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final status = await NetworkDetectionService.checkNetworkStatus();
      if (mounted) {
        setState(() {
          // Check if connection status changed
          final previousCanShare = _networkStatus?.canShare ?? false;
          final previousConnectionType = _networkStatus?.connectionType;

          _networkStatus = status;
          _isLoading = false;

          // Show notification if connection status changed
          if (previousCanShare != status.canShare ||
              previousConnectionType != status.connectionType) {
            _showConnectionChangeNotification(status, previousCanShare);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showConnectionChangeNotification(
    NetworkStatus status,
    bool previousCanShare,
  ) {
    // Don't show notification on initial load
    if (_networkStatus == null) return;

    String message;
    IconData icon;
    Color? backgroundColor;

    if (status.canShare && !previousCanShare) {
      // Connection established
      switch (status.connectionType) {
        case NetworkConnectionType.wifi:
          message = '✓ WiFi connected successfully!';
          icon = Icons.wifi;
          backgroundColor = Colors.green;
          break;
        case NetworkConnectionType.hotspot:
          message = '✓ Hotspot activated successfully!';
          icon = Icons.wifi_tethering;
          backgroundColor = Colors.blue;
          break;
        case NetworkConnectionType.mobile:
          message = '✓ Mobile data connected!';
          icon = Icons.signal_cellular_4_bar;
          backgroundColor = Colors.orange;
          break;
        default:
          message = '✓ Network connected!';
          icon = Icons.check_circle;
          backgroundColor = Colors.green;
      }
    } else if (!status.canShare && previousCanShare) {
      // Connection lost
      message = '✗ Network connection lost';
      icon = Icons.wifi_off;
      backgroundColor = Colors.red;
    } else {
      return; // No significant change
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        action: status.canShare
            ? SnackBarAction(
                label: 'Continue',
                textColor: Colors.white,
                onPressed: () {
                  Navigator.of(context).pop();
                },
              )
            : null,
      ),
    );
  }

  Future<void> _enableHotspot() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      // Try to enable hotspot programmatically
      final success = await HotspotService.createHotspot(
        networkName: HotspotService.generateNetworkName(),
        password: HotspotService.generatePassword(),
      );

      if (!success) {
        // If can't enable programmatically, redirect to settings
        _openHotspotSettings();
      } else {
        _showSnackBar('Hotspot enabled successfully!');
        _checkNetworkStatus(); // Refresh status
      }
    } catch (e) {
      _openHotspotSettings();
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _disableHotspot() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final success = await HotspotService.stopHotspot();
      if (!success) {
        _openHotspotSettings();
      } else {
        _showSnackBar('Hotspot disabled');
        _checkNetworkStatus(); // Refresh status
      }
    } catch (e) {
      _openHotspotSettings();
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _openWiFiSettings() {
    _showSnackBar('Opening WiFi settings...');
    HotspotService.openWiFiSettings();
  }

  void _openHotspotSettings() {
    _showSnackBar('Opening hotspot settings...');
    HotspotService.openHotspotSettings();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  IconData _getConnectionIcon() {
    if (_networkStatus?.canShare != true) {
      return Icons.wifi_off;
    }

    switch (_networkStatus?.connectionType) {
      case NetworkConnectionType.wifi:
        return Icons.wifi;
      case NetworkConnectionType.hotspot:
        return Icons.wifi_tethering;
      case NetworkConnectionType.mobile:
        return Icons.signal_cellular_4_bar;
      default:
        return Icons.wifi;
    }
  }

  String _getConnectionTitle() {
    if (_networkStatus?.canShare != true) {
      return 'No Network Connection';
    }

    switch (_networkStatus?.connectionType) {
      case NetworkConnectionType.wifi:
        return 'Connected via WiFi';
      case NetworkConnectionType.hotspot:
        return 'Hotspot Active';
      case NetworkConnectionType.mobile:
        return 'Connected via Mobile Data';
      default:
        return 'Network Connected';
    }
  }

  String _getConnectionSubtitle() {
    if (_networkStatus?.canShare != true) {
      return 'Choose an option below to connect';
    }

    switch (_networkStatus?.connectionType) {
      case NetworkConnectionType.wifi:
        return 'Ready to share files over WiFi network';
      case NetworkConnectionType.hotspot:
        return 'Other devices can connect to your hotspot';
      case NetworkConnectionType.mobile:
        return 'Ready to share files over mobile connection';
      default:
        return 'Ready to share files';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Setup'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _isLoading
                ? null
                : () {
                    _checkNetworkStatus();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Refreshing network status...'),
                        duration: Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Refresh network status',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Checking network status...'),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Network Status Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _networkStatus?.canShare == true
                            ? colorScheme.primaryContainer.withValues(
                                alpha: 0.3,
                              )
                            : colorScheme.errorContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _networkStatus?.canShare == true
                              ? colorScheme.primary.withValues(alpha: 0.3)
                              : colorScheme.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                _getConnectionIcon(),
                                color: _networkStatus?.canShare == true
                                    ? colorScheme.primary
                                    : colorScheme.error,
                                size: 48,
                              ),
                              // Show a subtle pulse animation when monitoring
                              if (!_isLoading)
                                Positioned(
                                  top: -2,
                                  right: -2,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: _networkStatus?.canShare == true
                                          ? Colors.green
                                          : Colors.grey,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.circle,
                                      size: 8,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _getConnectionTitle(),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              if (!_isLoading) ...[
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.refresh,
                                  size: 16,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _getConnectionSubtitle(),
                            style: TextStyle(
                              fontSize: 16,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_networkStatus?.localIP != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'IP: ${_networkStatus!.localIP}',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Connection Options
                    if (_networkStatus?.canShare != true) ...[
                      Text(
                        'Connection Options',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Choose how you want to connect for file sharing',
                        style: TextStyle(
                          fontSize: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // WiFi Option
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.wifi,
                                    color: colorScheme.primary,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Connect to WiFi',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Connect to an existing WiFi network to share files',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _isProcessing
                                      ? null
                                      : _openWiFiSettings,
                                  icon: const Icon(Icons.settings),
                                  label: const Text('Open WiFi Settings'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Hotspot Option
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.wifi_tethering,
                                    color: colorScheme.secondary,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Create Hotspot',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Create a hotspot for others to connect to your device',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: FilledButton.icon(
                                      onPressed: _isProcessing
                                          ? null
                                          : _enableHotspot,
                                      icon: _isProcessing
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.power_settings_new,
                                            ),
                                      label: Text(
                                        _isProcessing
                                            ? 'Starting...'
                                            : 'Start Hotspot',
                                      ),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: colorScheme.secondary,
                                        foregroundColor:
                                            colorScheme.onSecondary,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _isProcessing
                                          ? null
                                          : _openHotspotSettings,
                                      icon: const Icon(Icons.settings),
                                      label: const Text('Settings'),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      // Connected - Show options to disconnect or continue
                      // const Spacer(),
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Continue with File Sharing'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      OutlinedButton.icon(
                        onPressed: _isProcessing ? null : _disableHotspot,
                        icon: _isProcessing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.wifi_off),
                        label: Text(
                          _isProcessing ? 'Stopping...' : 'Stop Hotspot',
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],

                    // const Spacer(),

                    // Instructions
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'How it works',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _networkStatus?.canShare == true
                                ? '✓ You\'re connected and ready to share files\n'
                                      '• Use the main app to send or receive files\n'
                                      '• Both devices must be on the same network'
                                : '• WiFi: Connect to existing network (both devices)\n'
                                      '• Hotspot: Create network for others to join\n'
                                      '• Both devices need same network connection',
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.onSurface,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
