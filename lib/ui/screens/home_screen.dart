import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/navigation_service.dart';
import '../../services/network_detection_service.dart';
import 'offline_setup_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  NetworkStatus? _networkStatus;
  bool _isCheckingNetwork = true;
  StreamSubscription<NetworkStatus>? _networkSubscription;
  Timer? _networkTimer;

  @override
  void initState() {
    super.initState();
    _startNetworkMonitoring();
  }

  @override
  void dispose() {
    _networkSubscription?.cancel();
    _networkTimer?.cancel();
    super.dispose();
  }

  void _startNetworkMonitoring() {
    // Initial check
    _checkNetworkStatus();

    // Set up periodic monitoring every 3 seconds
    _networkTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        _checkNetworkStatus();
      }
    });
  }

  Future<void> _checkNetworkStatus() async {
    try {
      final status = await NetworkDetectionService.checkNetworkStatus();
      if (mounted) {
        setState(() {
          // Only update if the status actually changed
          if (_networkStatus?.connectionType != status.connectionType ||
              _networkStatus?.canShare != status.canShare ||
              _networkStatus?.localIP != status.localIP) {
            _networkStatus = status;

            // Show a brief notification when connection changes
            if (!_isCheckingNetwork && _networkStatus != null) {
              _showConnectionChangeNotification(status);
            }
          }
          _isCheckingNetwork = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingNetwork = false;
        });
      }
    }
  }

  void _showConnectionChangeNotification(NetworkStatus status) {
    String message;
    IconData icon;
    Color? backgroundColor;

    switch (status.connectionType) {
      case NetworkConnectionType.wifi:
        message = 'Connected to WiFi';
        icon = Icons.wifi;
        backgroundColor = Colors.green;
        break;
      case NetworkConnectionType.hotspot:
        message = 'Hotspot is active';
        icon = Icons.wifi_tethering;
        backgroundColor = Colors.blue;
        break;
      case NetworkConnectionType.mobile:
        message = 'Connected via mobile data';
        icon = Icons.signal_cellular_4_bar;
        backgroundColor = Colors.orange;
        break;
      default:
        if (!status.canShare) {
          message = 'Network disconnected';
          icon = Icons.wifi_off;
          backgroundColor = Colors.red;
        } else {
          return; // Don't show notification for unknown but working connections
        }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline File Sharing'),
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        actions: [
          IconButton(
            onPressed: _isCheckingNetwork
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
            icon: _isCheckingNetwork
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Refresh network status',
          ),
        ],
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header section
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.share, size: 80, color: colorScheme.primary),
                    const SizedBox(height: 24),
                    Text(
                      'Share Files Offline',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Transfer files between devices using local Wi-Fi without internet connection',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // Action buttons section
              Expanded(
                flex: 3,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Send File Button
                    SizedBox(
                      width: double.infinity,
                      height: 120,
                      child: Card(
                        elevation: 2,
                        child: InkWell(
                          onTap: () => _navigateToSendScreen(context),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _networkStatus?.canShare == true
                                      ? Icons.upload_file
                                      : Icons.warning_amber,
                                  size: 40,
                                  color: _networkStatus?.canShare == true
                                      ? colorScheme.primary
                                      : colorScheme.error,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Send File',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _networkStatus?.canShare == true
                                      ? 'Share a file with nearby devices'
                                      : 'Tap to setup network connection',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: _networkStatus?.canShare == true
                                        ? colorScheme.onSurfaceVariant
                                        : colorScheme.error,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Receive File Button
                    SizedBox(
                      width: double.infinity,
                      height: 120,
                      child: Card(
                        elevation: 2,
                        child: InkWell(
                          onTap: () => _navigateToReceiveScreen(context),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _networkStatus?.canShare == true
                                      ? Icons.download
                                      : Icons.warning_amber,
                                  size: 40,
                                  color: _networkStatus?.canShare == true
                                      ? colorScheme.secondary
                                      : colorScheme.error,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Receive File',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _networkStatus?.canShare == true
                                      ? 'Scan QR code to receive files'
                                      : 'Tap to setup network connection',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: _networkStatus?.canShare == true
                                        ? colorScheme.onSurfaceVariant
                                        : colorScheme.error,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Network status and offline setup section
              Expanded(
                flex: 1,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (_isCheckingNetwork)
                      const CircularProgressIndicator()
                    else if (_networkStatus != null &&
                        !_networkStatus!.canShare) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer.withValues(
                            alpha: 0.3,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: colorScheme.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.wifi_off,
                                  size: 16,
                                  color: colorScheme.error,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'No network connection',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.error,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _navigateToOfflineSetup,
                              icon: const Icon(Icons.settings, size: 16),
                              label: const Text('Setup Offline Sharing'),
                              style: TextButton.styleFrom(
                                foregroundColor: colorScheme.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _getConnectionIcon(),
                            size: 16,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _getConnectionStatusText(),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToSendScreen(BuildContext context) {
    if (_networkStatus?.canShare == true) {
      NavigationService.navigateToSend();
    } else {
      _showNetworkRequiredMessage('send files');
      _navigateToOfflineSetup();
    }
  }

  void _navigateToReceiveScreen(BuildContext context) {
    if (_networkStatus?.canShare == true) {
      NavigationService.navigateToReceive();
    } else {
      _showNetworkRequiredMessage('receive files');
      _navigateToOfflineSetup();
    }
  }

  void _showNetworkRequiredMessage(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Network connection required to $action'),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Setup',
          textColor: Theme.of(context).colorScheme.onError,
          onPressed: () {
            // The navigation will happen anyway, this just dismisses the snackbar
          },
        ),
      ),
    );
  }

  void _navigateToOfflineSetup() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const OfflineSetupScreen()));
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

  String _getConnectionStatusText() {
    if (_networkStatus?.canShare != true) {
      return 'Works without internet';
    }

    switch (_networkStatus?.connectionType) {
      case NetworkConnectionType.wifi:
        return 'Connected via WiFi';
      case NetworkConnectionType.hotspot:
        return 'Connected via Hotspot';
      case NetworkConnectionType.mobile:
        return 'Connected via Mobile Data';
      default:
        return 'Ready to share files';
    }
  }
}
