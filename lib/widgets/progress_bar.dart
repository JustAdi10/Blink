import 'package:flutter/material.dart';
import '../models/transfer_info.dart';

class TransferProgressBar extends StatelessWidget {
  final TransferInfo transferInfo;
  final double? height;
  final Color? backgroundColor;
  final Color? progressColor;

  const TransferProgressBar({
    super.key,
    required this.transferInfo,
    this.height,
    this.backgroundColor,
    this.progressColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      height: height ?? 8.0,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4.0),
        color: backgroundColor ?? colorScheme.surfaceVariant,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4.0),
        child: LinearProgressIndicator(
          value: transferInfo.progress,
          backgroundColor: Colors.transparent,
          valueColor: AlwaysStoppedAnimation<Color>(
            progressColor ?? _getProgressColor(colorScheme),
          ),
        ),
      ),
    );
  }

  Color _getProgressColor(ColorScheme colorScheme) {
    switch (transferInfo.status) {
      case TransferStatus.completed:
        return colorScheme.primary;
      case TransferStatus.failed:
        return colorScheme.error;
      case TransferStatus.inProgress:
        return colorScheme.primary;
      case TransferStatus.pending:
        return colorScheme.outline;
    }
  }
}

class TransferProgressCard extends StatelessWidget {
  final TransferInfo transferInfo;
  final VoidCallback? onTap;

  const TransferProgressCard({
    super.key,
    required this.transferInfo,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _getStatusIcon(),
                    color: _getStatusColor(colorScheme),
                    size: 20.0,
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Text(
                      transferInfo.fileName,
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    _getStatusText(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _getStatusColor(colorScheme),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8.0),
              TransferProgressBar(transferInfo: transferInfo),
              const SizedBox(height: 4.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatFileSize(transferInfo.fileSize),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '${(transferInfo.progress * 100).toInt()}%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              if (transferInfo.errorMessage != null) ...[
                const SizedBox(height: 8.0),
                Text(
                  transferInfo.errorMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _getStatusIcon() {
    switch (transferInfo.status) {
      case TransferStatus.completed:
        return Icons.check_circle;
      case TransferStatus.failed:
        return Icons.error;
      case TransferStatus.inProgress:
        return transferInfo.type == TransferType.sending 
            ? Icons.upload 
            : Icons.download;
      case TransferStatus.pending:
        return Icons.pending;
    }
  }

  Color _getStatusColor(ColorScheme colorScheme) {
    switch (transferInfo.status) {
      case TransferStatus.completed:
        return colorScheme.primary;
      case TransferStatus.failed:
        return colorScheme.error;
      case TransferStatus.inProgress:
        return colorScheme.primary;
      case TransferStatus.pending:
        return colorScheme.outline;
    }
  }

  String _getStatusText() {
    switch (transferInfo.status) {
      case TransferStatus.completed:
        return 'Completed';
      case TransferStatus.failed:
        return 'Failed';
      case TransferStatus.inProgress:
        return transferInfo.type == TransferType.sending 
            ? 'Sending...' 
            : 'Receiving...';
      case TransferStatus.pending:
        return 'Pending';
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
