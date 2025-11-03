import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../services/file_server_service.dart';
import '../../services/qr_code_service.dart';
import '../../core/models/file_transfer_session.dart';
import '../../core/models/transfer_progress.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final FileServerService _fileServerService = FileServerService();
  final QRCodeService _qrCodeService = QRCodeService();

  File? _selectedFile;
  FileTransferSession? _currentSession;
  TransferProgress? _transferProgress;
  bool _isServerStarting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fileServerService.progressStream.listen((progress) {
      if (mounted) {
        setState(() {
          _transferProgress = progress;
        });

        // Handle transfer completion
        if (progress.isComplete && _currentSession != null) {
          _handleTransferCompletion();
        }
      }
    });
  }

  @override
  void dispose() {
    _fileServerService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Send File'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        actions: [
          if (_fileServerService.isRunning)
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: _stopServer,
              tooltip: 'Stop Server',
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Server Status Indicator
              _buildServerStatusCard(colorScheme),
              const SizedBox(height: 24),

              // File Selection Section
              if (!_fileServerService.isRunning) ...[
                _buildFileSelectionSection(colorScheme),
              ] else ...[
                // QR Code Display Section
                _buildQRCodeSection(colorScheme),

                // Transfer Progress Section
                if (_transferProgress != null)
                  _buildTransferProgressSection(colorScheme),
              ],

              // Error Display
              if (_errorMessage != null) _buildErrorDisplay(colorScheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServerStatusCard(ColorScheme colorScheme) {
    final theme = Theme.of(context);
    final isRunning = _fileServerService.isRunning;
    final isStarting = _isServerStarting;

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (isStarting) {
      statusColor = colorScheme.tertiary;
      statusIcon = Icons.hourglass_empty;
      statusText = 'Starting Server...';
    } else if (isRunning) {
      statusColor = colorScheme.primary;
      statusIcon = Icons.wifi_tethering;
      statusText = 'Server Running';
    } else {
      statusColor = colorScheme.outline;
      statusIcon = Icons.wifi_tethering_off;
      statusText = 'Server Stopped';
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(statusIcon, color: statusColor, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusText,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (isRunning && _currentSession != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${_currentSession!.ipAddress}:${_currentSession!.port}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      'Sharing: ${_currentSession!.fileName}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ] else if (isStarting) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Initializing network connection...',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isRunning)
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileSelectionSection(ColorScheme colorScheme) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _selectedFile != null ? Icons.description : Icons.upload_file,
            size: 80,
            color: _selectedFile != null
                ? colorScheme.primary
                : colorScheme.outline,
          ),
          const SizedBox(height: 24),

          if (_selectedFile != null) ...[
            Text(
              _selectedFile!.path.split('/').last,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            FutureBuilder<int>(
              future: _selectedFile!.length(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Text(
                    _formatFileSize(snapshot.data!),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            const SizedBox(height: 32),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('Change File'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isServerStarting ? null : _startServer,
                    icon: _isServerStarting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.qr_code),
                    label: Text(
                      _isServerStarting ? 'Starting...' : 'Share File',
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Text(
              'Select a file to share',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Choose any file from your device to share with nearby devices',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            FilledButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.folder_open),
              label: const Text('Choose File'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQRCodeSection(ColorScheme colorScheme) {
    final theme = Theme.of(context);
    if (_currentSession == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final qrData = _qrCodeService.generateQRData(_currentSession!);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Scan to Download',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _currentSession!.fileName,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        // QR Code with proper sizing and contrast
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: QrImageView(
            data: qrData,
            version: QrVersions.auto,
            size: 280,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Colors.black,
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Colors.black,
            ),
            errorCorrectionLevel: QrErrorCorrectLevel.M,
            padding: const EdgeInsets.all(8),
          ),
        ),

        const SizedBox(height: 24),
        Text(
          'Point the receiving device\'s camera at this QR code',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildTransferProgressSection(ColorScheme colorScheme) {
    final theme = Theme.of(context);
    if (_transferProgress == null) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Transfer Progress',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${_transferProgress!.percentage.toStringAsFixed(1)}%',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            LinearProgressIndicator(
              value: _transferProgress!.percentage / 100,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),

            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _transferProgress!.formattedSpeed,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (!_transferProgress!.isComplete)
                  Text(
                    _transferProgress!.formattedETA,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),

            if (_transferProgress!.isComplete) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: colorScheme.primary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Transfer completed successfully',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    try {
      setState(() {
        _errorMessage = null;
      });

      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to pick file: ${e.toString()}';
      });
    }
  }

  Future<void> _startServer() async {
    if (_selectedFile == null) return;

    setState(() {
      _isServerStarting = true;
      _errorMessage = null;
    });

    try {
      // Validate file exists and is readable
      if (!await _selectedFile!.exists()) {
        throw FileSystemException(
          'Selected file no longer exists',
          _selectedFile!.path,
        );
      }

      final session = await _fileServerService.startServer(_selectedFile!);
      setState(() {
        _currentSession = session;
        _isServerStarting = false;
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Server started successfully! Share the QR code to receive files.',
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isServerStarting = false;
        _errorMessage = _getErrorMessage(e);
      });
    }
  }

  Future<void> _stopServer() async {
    try {
      await _fileServerService.stopServer();
      setState(() {
        _currentSession = null;
        _transferProgress = null;
        _selectedFile = null;
      });

      // Show confirmation message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Server stopped successfully'),
            backgroundColor: Theme.of(context).colorScheme.secondary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = _getErrorMessage(e);
      });
    }
  }

  void _clearError() {
    setState(() {
      _errorMessage = null;
    });
  }

  Widget _buildErrorDisplay(ColorScheme colorScheme) {
    final showRetry =
        _errorMessage!.contains('Network error') ||
        _errorMessage!.contains('Failed to start server');

    return Card(
      elevation: 2,
      color: colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            if (showRetry) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _clearError,
                    child: Text(
                      'Dismiss',
                      style: TextStyle(color: colorScheme.onErrorContainer),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _isServerStarting
                        ? null
                        : () {
                            _clearError();
                            if (_selectedFile != null) {
                              _startServer();
                            }
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.onErrorContainer,
                      foregroundColor: colorScheme.errorContainer,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _clearError,
                  child: Text(
                    'Dismiss',
                    style: TextStyle(color: colorScheme.onErrorContainer),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _handleTransferCompletion() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('File transfer completed successfully!'),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Send Another',
            textColor: Theme.of(context).colorScheme.onPrimary,
            onPressed: () {
              setState(() {
                _selectedFile = null;
                _currentSession = null;
                _transferProgress = null;
              });
            },
          ),
        ),
      );
    }
  }

  String _getErrorMessage(dynamic error) {
    if (error is FileSystemException) {
      return 'File error: ${error.message}';
    } else if (error is StateError) {
      if (error.message.contains('IP address')) {
        return 'Network error: Unable to detect your device\'s IP address. Please check your Wi-Fi connection.';
      } else if (error.message.contains('port')) {
        return 'Network error: No available ports found. Please try again.';
      }
      return 'Network error: ${error.message}';
    } else if (error.toString().contains('SocketException')) {
      return 'Network error: Unable to start server. Please check your network connection and try again.';
    } else if (error.toString().contains('Permission')) {
      return 'Permission error: Unable to access network or file. Please check app permissions.';
    }
    return 'Unexpected error: ${error.toString()}';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
