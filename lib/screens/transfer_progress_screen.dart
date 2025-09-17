import 'dart:async';
import 'package:flutter/material.dart';
import '../services/transfer_service.dart';
import '../services/mock_transfer_service.dart';
// import '../services/real_transfer_service.dart';
import '../models/transfer_info.dart';
import '../widgets/progress_bar.dart';

class TransferProgressScreen extends StatefulWidget {
  const TransferProgressScreen({super.key});

  @override
  State<TransferProgressScreen> createState() => _TransferProgressScreenState();
}

class _TransferProgressScreenState extends State<TransferProgressScreen> {
  final TransferService _transferService = TransferService();
  final MockTransferService _mockTransferService = MockTransferService();
  // final RealTransferService _realTransferService = RealTransferService();
  
  List<TransferInfo> _transfers = [];
  StreamSubscription<TransferInfo>? _transferSubscription;

  @override
  void initState() {
    super.initState();
    _initializeTransfers();
  }

  void _initializeTransfers() {
    setState(() {
      _transfers = _mockTransferService.getActiveTransfers();
    });

    _transferSubscription = _mockTransferService.transferStream.listen((transfer) {
      setState(() {
        _transfers = _mockTransferService.getActiveTransfers();
      });
    });
  }

  @override
  void dispose() {
    _transferSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer Progress'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      body: _transfers.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_upload_outlined,
                    size: 64.0,
                    color: colorScheme.outline,
                  ),
                  const SizedBox(height: 16.0),
                  Text(
                    'No active transfers',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    'Start a file transfer to see progress here',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Summary section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16.0),
                  color: colorScheme.surfaceVariant.withOpacity(0.3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transfer Summary',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      Row(
                        children: [
                          _buildSummaryItem(
                            'Total',
                            _transfers.length.toString(),
                            colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 16.0),
                          _buildSummaryItem(
                            'In Progress',
                            _transfers.where((t) => t.status == TransferStatus.inProgress).length.toString(),
                            colorScheme.primary,
                          ),
                          const SizedBox(width: 16.0),
                          _buildSummaryItem(
                            'Completed',
                            _transfers.where((t) => t.status == TransferStatus.completed).length.toString(),
                            colorScheme.primary,
                          ),
                          const SizedBox(width: 16.0),
                          _buildSummaryItem(
                            'Failed',
                            _transfers.where((t) => t.status == TransferStatus.failed).length.toString(),
                            colorScheme.error,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Transfers list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _transfers.length,
                    itemBuilder: (context, index) {
                      final transfer = _transfers[index];
                      return TransferProgressCard(
                        transferInfo: transfer,
                        onTap: () => _showTransferDetails(transfer),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: color,
          ),
        ),
      ],
    );
  }

  void _showTransferDetails(TransferInfo transfer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(transfer.fileName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Type', transfer.type == TransferType.sending ? 'Sending' : 'Receiving'),
            _buildDetailRow('Status', _getStatusText(transfer.status)),
            _buildDetailRow('Size', _formatFileSize(transfer.fileSize)),
            _buildDetailRow('Progress', '${(transfer.progress * 100).toInt()}%'),
            _buildDetailRow('Started', _formatDateTime(transfer.startTime)),
            if (transfer.endTime != null)
              _buildDetailRow('Completed', _formatDateTime(transfer.endTime!)),
            if (transfer.errorMessage != null) ...[
              const SizedBox(height: 8.0),
              Text(
                'Error:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4.0),
              Text(
                transfer.errorMessage!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 16.0),
            TransferProgressBar(transferInfo: transfer),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          if (transfer.status == TransferStatus.completed && transfer.filePath != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // File will be opened automatically by TransferService
              },
              child: const Text('Open File'),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80.0,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(TransferStatus status) {
    switch (status) {
      case TransferStatus.completed:
        return 'Completed';
      case TransferStatus.failed:
        return 'Failed';
      case TransferStatus.inProgress:
        return 'In Progress';
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

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
