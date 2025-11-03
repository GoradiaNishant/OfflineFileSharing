import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '../../core/services/status_update_service.dart';
import '../../core/models/transfer_progress.dart';
import 'progress_indicators.dart';

/// Comprehensive status display widget
class StatusDisplay extends StatelessWidget {
  final bool showProgress;
  final bool showDetails;
  final bool compact;

  const StatusDisplay({
    super.key,
    this.showProgress = true,
    this.showDetails = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState(),
      builder: (context, _) {
        final appState = AppState();
        final status = appState.currentStatus;
        final progress = appState.transferProgress;
        final state = appState.transferState;

        if (state == TransferState.idle && status == null) {
          return const SizedBox.shrink();
        }

        if (compact) {
          return _buildCompactStatus(context, state, status, progress);
        }

        return _buildFullStatus(context, state, status, progress);
      },
    );
  }

  Widget _buildCompactStatus(
    BuildContext context,
    TransferState state,
    TransferStatusUpdate? status,
    TransferProgress? progress,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _getStateColor(state).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _getStateColor(state).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getStateIcon(state), size: 16, color: _getStateColor(state)),
          const SizedBox(width: 6),
          Text(
            state.displayName,
            style: theme.textTheme.bodySmall?.copyWith(
              color: _getStateColor(state),
              fontWeight: FontWeight.w500,
            ),
          ),
          if (progress != null && state == TransferState.transferring) ...[
            const SizedBox(width: 8),
            Text(
              '${progress.percentage.toStringAsFixed(0)}%',
              style: theme.textTheme.bodySmall?.copyWith(
                color: _getStateColor(state),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFullStatus(
    BuildContext context,
    TransferState state,
    TransferStatusUpdate? status,
    TransferProgress? progress,
  ) {
    final theme = Theme.of(context);

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status header
            Row(
              children: [
                Icon(
                  _getStateIcon(state),
                  color: _getStateColor(state),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.displayName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: _getStateColor(state),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (status?.message != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          status!.message!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (status?.timestamp != null)
                  Text(
                    _formatTimestamp(status!.timestamp),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),

            // Progress indicator
            if (showProgress &&
                progress != null &&
                state == TransferState.transferring) ...[
              const SizedBox(height: 16),
              FileTransferProgressIndicator(
                progress: progress,
                showDetails: showDetails,
                onCancel: () {
                  AppState().transferCancelled();
                },
              ),
            ],

            // File information
            if (showDetails && status?.fileName != null) ...[
              const SizedBox(height: 12),
              _buildFileInfo(context, status!),
            ],

            // Metadata information
            if (showDetails && status?.metadata != null) ...[
              const SizedBox(height: 8),
              _buildMetadataInfo(context, status!.metadata!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFileInfo(BuildContext context, TransferStatusUpdate status) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.insert_drive_file,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.fileName!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (status.metadata?['fileSize'] != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    _formatFileSize(status.metadata!['fileSize'] as int),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataInfo(
    BuildContext context,
    Map<String, dynamic> metadata,
  ) {
    final theme = Theme.of(context);
    final relevantMetadata = <String, String>{};

    // Extract relevant metadata for display
    if (metadata['ipAddress'] != null && metadata['port'] != null) {
      relevantMetadata['Connection'] =
          '${metadata['ipAddress']}:${metadata['port']}';
    }

    if (metadata['sessionId'] != null) {
      relevantMetadata['Session'] =
          metadata['sessionId'].toString().substring(0, 8) + '...';
    }

    if (metadata['error'] != null) {
      relevantMetadata['Error'] = metadata['error'].toString();
    }

    if (relevantMetadata.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: relevantMetadata.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  '${entry.key}:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: Text(entry.value, style: theme.textTheme.bodySmall),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  IconData _getStateIcon(TransferState state) {
    switch (state) {
      case TransferState.idle:
        return Icons.radio_button_unchecked;
      case TransferState.serverStarted:
        return Icons.wifi_tethering;
      case TransferState.serverStopped:
        return Icons.wifi_tethering_off;
      case TransferState.qrScanned:
        return Icons.qr_code_scanner;
      case TransferState.connecting:
        return Icons.wifi_find;
      case TransferState.connected:
        return Icons.wifi;
      case TransferState.transferring:
        return Icons.sync;
      case TransferState.completed:
        return Icons.check_circle;
      case TransferState.error:
        return Icons.error;
      case TransferState.cancelled:
        return Icons.cancel;
    }
  }

  Color _getStateColor(TransferState state) {
    switch (state) {
      case TransferState.idle:
        return Colors.grey;
      case TransferState.serverStarted:
      case TransferState.connecting:
      case TransferState.connected:
      case TransferState.transferring:
        return Colors.blue;
      case TransferState.qrScanned:
        return Colors.orange;
      case TransferState.completed:
        return Colors.green;
      case TransferState.error:
        return Colors.red;
      case TransferState.cancelled:
        return Colors.orange;
      case TransferState.serverStopped:
        return Colors.grey;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }

  String _formatFileSize(int bytes) {
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

/// Simple status indicator for app bars
class StatusIndicator extends StatelessWidget {
  const StatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState(),
      builder: (context, _) {
        final state = AppState().transferState;

        if (state == TransferState.idle) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getStateColor(state),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_getStateIcon(state), size: 12, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                state.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getStateIcon(TransferState state) {
    switch (state) {
      case TransferState.idle:
        return Icons.radio_button_unchecked;
      case TransferState.serverStarted:
        return Icons.wifi_tethering;
      case TransferState.serverStopped:
        return Icons.wifi_tethering_off;
      case TransferState.qrScanned:
        return Icons.qr_code_scanner;
      case TransferState.connecting:
        return Icons.wifi_find;
      case TransferState.connected:
        return Icons.wifi;
      case TransferState.transferring:
        return Icons.sync;
      case TransferState.completed:
        return Icons.check_circle;
      case TransferState.error:
        return Icons.error;
      case TransferState.cancelled:
        return Icons.cancel;
    }
  }

  Color _getStateColor(TransferState state) {
    switch (state) {
      case TransferState.idle:
        return Colors.grey;
      case TransferState.serverStarted:
      case TransferState.connecting:
      case TransferState.connected:
      case TransferState.transferring:
        return Colors.blue;
      case TransferState.qrScanned:
        return Colors.orange;
      case TransferState.completed:
        return Colors.green;
      case TransferState.error:
        return Colors.red;
      case TransferState.cancelled:
        return Colors.orange;
      case TransferState.serverStopped:
        return Colors.grey;
    }
  }
}
