import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';
import 'core/navigation_service.dart';
import 'core/services/platform_optimization_service.dart';
import 'ui/widgets/error_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize desktop-specific features
  if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      size: Size(1000, 700),
      minimumSize: Size(800, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      windowButtonVisibility: true,
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // Initialize platform-specific optimizations
  final platformService = PlatformOptimizationService();
  await platformService.initialize();

  if (kDebugMode) {
    print('Platform info: ${platformService.getPlatformInfo()}');
  }

  runApp(const OfflineFileSharingApp());
}

class OfflineFileSharingApp extends StatelessWidget {
  const OfflineFileSharingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ErrorHandler(
      child: MaterialApp(
        title: 'Offline File Sharing',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(centerTitle: true),
          cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          snackBarTheme: const SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
          ),
        ),
        navigatorKey: NavigationService.navigatorKey,
        onGenerateRoute: NavigationService.generateRoute,
        initialRoute: NavigationService.home,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
