import 'dart:io';
import '../services/platform_optimization_service.dart';

/// Utility class for network-related operations
class NetworkUtils {
  /// Discovers the local IP address of the device with interface prioritization
  static Future<String?> getLocalIPAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      // Priority order: Wi-Fi > Ethernet > Others
      final prioritizedInterfaces = _prioritizeInterfaces(interfaces);

      for (final interface in prioritizedInterfaces) {
        for (final address in interface.addresses) {
          if (_isValidLocalAddress(address)) {
            return address.address;
          }
        }
      }

      // Fallback: return any valid local address
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (_isValidLocalAddress(address)) {
            return address.address;
          }
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Gets all available local IP addresses with their interface names
  static Future<List<NetworkInterfaceInfo>> getAllLocalAddresses() async {
    final List<NetworkInterfaceInfo> result = [];

    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (_isValidLocalAddress(address)) {
            result.add(
              NetworkInterfaceInfo(
                name: interface.name,
                address: address.address,
                type: _getInterfaceType(interface.name),
              ),
            );
          }
        }
      }

      // Sort by priority
      result.sort((a, b) => a.type.priority.compareTo(b.type.priority));

      return result;
    } catch (e) {
      return result;
    }
  }

  /// Validates if a network connection can be established to the given address
  static Future<bool> validateConnection(
    String ipAddress,
    int port, {
    Duration? timeout,
  }) async {
    try {
      // Use platform-specific timeout if not provided
      final platformService = PlatformOptimizationService();
      final config = platformService.getNetworkConfig();
      final connectionTimeout =
          timeout ?? Duration(milliseconds: config['connectionTimeout'] as int);

      final socket = await Socket.connect(
        ipAddress,
        port,
        timeout: connectionTimeout,
      );
      await socket.close();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Checks if the device is connected to a Wi-Fi network
  static Future<bool> isConnectedToWiFi() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      return interfaces.any(
        (interface) =>
            _getInterfaceType(interface.name) == NetworkInterfaceType.wifi &&
            interface.addresses.any(_isValidLocalAddress),
      );
    } catch (e) {
      return false;
    }
  }

  /// Finds an available port in the given range
  static Future<int?> findAvailablePort({
    int startPort = 8080,
    int endPort = 8090,
  }) async {
    for (int port = startPort; port <= endPort; port++) {
      try {
        final serverSocket = await ServerSocket.bind(
          InternetAddress.anyIPv4,
          port,
        );
        await serverSocket.close();
        return port;
      } catch (e) {
        // Port is not available, try next one
        continue;
      }
    }
    return null;
  }

  /// Prioritizes network interfaces based on type preference
  static List<NetworkInterface> _prioritizeInterfaces(
    List<NetworkInterface> interfaces,
  ) {
    final wifi = <NetworkInterface>[];
    final ethernet = <NetworkInterface>[];
    final others = <NetworkInterface>[];

    for (final interface in interfaces) {
      final type = _getInterfaceType(interface.name);
      switch (type) {
        case NetworkInterfaceType.wifi:
          wifi.add(interface);
          break;
        case NetworkInterfaceType.ethernet:
          ethernet.add(interface);
          break;
        case NetworkInterfaceType.other:
          others.add(interface);
          break;
      }
    }

    return [...wifi, ...ethernet, ...others];
  }

  /// Determines the type of network interface based on its name
  static NetworkInterfaceType _getInterfaceType(String interfaceName) {
    final name = interfaceName.toLowerCase();

    // Wi-Fi interface patterns
    if (name.contains('wlan') ||
        name.contains('wifi') ||
        name.startsWith('en0') || // iOS/macOS Wi-Fi
        name.startsWith('wlp') || // Linux Wi-Fi
        name.contains('wireless') ||
        name.contains('wi-fi') ||
        name.startsWith('wl') || // Windows Wi-Fi
        name.contains('802.11')) {
      return NetworkInterfaceType.wifi;
    }

    // Ethernet interface patterns
    if (name.contains('eth') ||
        name.startsWith('en1') || // iOS/macOS Ethernet
        name.startsWith('enp') || // Linux Ethernet
        name.contains('lan') ||
        name.contains('ethernet') ||
        name.startsWith('em') || // FreeBSD/macOS Ethernet
        name.startsWith('igb') || // Intel Ethernet
        name.startsWith('re') || // Realtek Ethernet
        name.contains('local area connection')) {
      // Windows Ethernet
      return NetworkInterfaceType.ethernet;
    }

    return NetworkInterfaceType.other;
  }

  /// Validates if an IP address is a valid local network address
  static bool _isValidLocalAddress(InternetAddress address) {
    if (address.type != InternetAddressType.IPv4) return false;

    final ip = address.address;
    final parts = ip.split('.');

    if (parts.length != 4) return false;

    try {
      final first = int.parse(parts[0]);
      final second = int.parse(parts[1]);

      // Check for private IP ranges
      // 10.0.0.0/8
      if (first == 10) return true;

      // 172.16.0.0/12
      if (first == 172 && second >= 16 && second <= 31) return true;

      // 192.168.0.0/16
      if (first == 192 && second == 168) return true;

      // Link-local addresses 169.254.0.0/16
      if (first == 169 && second == 254) return true;

      return false;
    } catch (e) {
      return false;
    }
  }
}

/// Information about a network interface
class NetworkInterfaceInfo {
  final String name;
  final String address;
  final NetworkInterfaceType type;

  const NetworkInterfaceInfo({
    required this.name,
    required this.address,
    required this.type,
  });

  @override
  String toString() {
    return 'NetworkInterfaceInfo(name: $name, address: $address, type: $type)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NetworkInterfaceInfo &&
        other.name == name &&
        other.address == address &&
        other.type == type;
  }

  @override
  int get hashCode => Object.hash(name, address, type);
}

/// Types of network interfaces with priority ordering
enum NetworkInterfaceType {
  wifi(priority: 1),
  ethernet(priority: 2),
  other(priority: 3);

  const NetworkInterfaceType({required this.priority});

  final int priority;
}
