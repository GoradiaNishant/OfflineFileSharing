import 'package:flutter/material.dart';
import '../../core/models/transfer_progress.dart';

/// Comprehensive progress indicator widget for file transfers
class FileTransferProgressIndicator extends StatelessWidget {
  final TransferProgress progress;
  final String? title;
  final bool showDetails;
  final bool showSpeed;
  final bool showETA;
  final VoidCallback? onCancel;
  final Color? progressColor;

  const FileTransferProgressIndicator({
    super.key,
    required this.progress,
    this.title,
    this.showDetails = true,
    this.showSpeed = true,
    this.showETA = true,
    this.onCancel,
    this.progressColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title and cancel button
            if (title != null || onCancel != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (title != null)
                    Text(
                      title!,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (onCancel != null)
                    IconButton(
                      onPressed: onCancel,
                      icon: const Icon(Icons.close),
                      tooltip: 'Cancel transfer',
                      iconSize: 20,
                    ),
                ],
              ),

            if (title != null || onCancel != null) const SizedBox(height: 12),

            // Progress bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: progress.percentage / 100.0,
                  backgroundColor: colorScheme.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progressColor ?? colorScheme.primary,
                  ),
                  minHeight: 8,
                ),
                const SizedBox(height: 8),

                // Percentage text
                Text(
                  '${progress.percentage.toStringAsFixed(1)}%',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: progressColor ?? colorScheme.primary,
                  ),
                ),
              ],
            ),

            if (showDetails) ...[
              const SizedBox(height: 12),

              // Transfer details
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // File size progress
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Progress',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          progress.formattedProgress,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),

                  // Speed
                  if (showSpeed && progress.hasStarted && !progress.isComplete)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Speed',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            progress.formattedSpeed,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),

                  // ETA
                  if (showETA && progress.hasStarted && !progress.isComplete)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'ETA',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            progress.formattedETA,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],

            // Completion status
            if (progress.isComplete) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Transfer completed successfully',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.green,
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
}

/// Compact progress indicator for smaller spaces
class CompactProgressIndicator extends StatelessWidget {
  final TransferProgress progress;
  final String? label;
  final bool showPercentage;
  final Color? progressColor;

  const CompactProgressIndicator({
    super.key,
    required this.progress,
    this.label,
    this.showPercentage = true,
    this.progressColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(label!, style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
        ],

        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: progress.percentage / 100.0,
                backgroundColor: colorScheme.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(
                  progressColor ?? colorScheme.primary,
                ),
                minHeight: 4,
              ),
            ),

            if (showPercentage) ...[
              const SizedBox(width: 8),
              Text(
                '${progress.percentage.toStringAsFixed(0)}%',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Circular progress indicator with status
class CircularTransferProgress extends StatelessWidget {
  final TransferProgress progress;
  final double size;
  final double strokeWidth;
  final Color? progressColor;
  final Color? backgroundColor;
  final bool showPercentage;
  final bool showSpeed;

  const CircularTransferProgress({
    super.key,
    required this.progress,
    this.size = 80,
    this.strokeWidth = 6,
    this.progressColor,
    this.backgroundColor,
    this.showPercentage = true,
    this.showSpeed = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Circular progress indicator
          CircularProgressIndicator(
            value: progress.percentage / 100.0,
            strokeWidth: strokeWidth,
            backgroundColor: backgroundColor ?? colorScheme.surfaceVariant,
            valueColor: AlwaysStoppedAnimation<Color>(
              progressColor ?? colorScheme.primary,
            ),
          ),

          // Center content
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (progress.isComplete)
                Icon(Icons.check, color: Colors.green, size: size * 0.3)
              else if (showPercentage)
                Text(
                  '${progress.percentage.toStringAsFixed(0)}%',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: size * 0.15,
                  ),
                ),

              if (showSpeed && progress.hasStarted && !progress.isComplete)
                Text(
                  progress.formattedSpeed,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: size * 0.08,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Status indicator with icon and message
class TransferStatusIndicator extends StatelessWidget {
  final TransferStatus status;
  final String message;
  final VoidCallback? onAction;
  final String? actionLabel;

  const TransferStatusIndicator({
    super.key,
    required this.status,
    required this.message,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getStatusColor(status, colorScheme).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getStatusColor(status, colorScheme).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getStatusIcon(status),
            color: _getStatusColor(status, colorScheme),
            size: 20,
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: _getStatusColor(status, colorScheme),
              ),
            ),
          ),

          if (onAction != null && actionLabel != null) ...[
            const SizedBox(width: 8),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }

  IconData _getStatusIcon(TransferStatus status) {
    switch (status) {
      case TransferStatus.idle:
        return Icons.radio_button_unchecked;
      case TransferStatus.connecting:
        return Icons.wifi_find;
      case TransferStatus.transferring:
        return Icons.sync;
      case TransferStatus.completed:
        return Icons.check_circle;
      case TransferStatus.error:
        return Icons.error;
      case TransferStatus.cancelled:
        return Icons.cancel;
    }
  }

  Color _getStatusColor(TransferStatus status, ColorScheme colorScheme) {
    switch (status) {
      case TransferStatus.idle:
        return colorScheme.onSurfaceVariant;
      case TransferStatus.connecting:
        return Colors.blue;
      case TransferStatus.transferring:
        return colorScheme.primary;
      case TransferStatus.completed:
        return Colors.green;
      case TransferStatus.error:
        return colorScheme.error;
      case TransferStatus.cancelled:
        return Colors.orange;
    }
  }
}

/// Transfer status enumeration
enum TransferStatus {
  idle,
  connecting,
  transferring,
  completed,
  error,
  cancelled,
}

/// Animated progress indicator with pulse effect
class AnimatedProgressIndicator extends StatefulWidget {
  final TransferProgress progress;
  final Duration animationDuration;
  final Color? progressColor;

  const AnimatedProgressIndicator({
    super.key,
    required this.progress,
    this.animationDuration = const Duration(milliseconds: 300),
    this.progressColor,
  });

  @override
  State<AnimatedProgressIndicator> createState() =>
      _AnimatedProgressIndicatorState();
}

class _AnimatedProgressIndicatorState extends State<AnimatedProgressIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _previousProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: widget.progress.percentage / 100.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedProgressIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.progress.percentage != widget.progress.percentage) {
      _previousProgress = _animation.value;
      _animation = Tween<double>(
        begin: _previousProgress,
        end: widget.progress.percentage / 100.0,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return LinearProgressIndicator(
          value: _animation.value,
          backgroundColor: colorScheme.surfaceVariant,
          valueColor: AlwaysStoppedAnimation<Color>(
            widget.progressColor ?? colorScheme.primary,
          ),
          minHeight: 8,
        );
      },
    );
  }
}
