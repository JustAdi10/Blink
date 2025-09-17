import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../models/transfer_info.dart';
import '../models/device_info.dart';

class MockTransferService {
  static final MockTransferService _instance = MockTransferService._internal();
  factory MockTransferService() => _instance;
  MockTransferService._internal();

  final StreamController<TransferInfo> _transferController = 
      StreamController<TransferInfo>.broadcast();
  final StreamController<TransferInfo> _completedTransferController = 
      StreamController<TransferInfo>.broadcast();

  Stream<TransferInfo> get transferStream => _transferController.stream;
  Stream<TransferInfo> get completedTransferStream => _completedTransferController.stream;

  final Map<String, TransferInfo> _activeTransfers = {};

  void initialize() {
    print('Mock transfer service initialized');
  }

  Future<TransferInfo?> sendFile(String filePath, DeviceInfo device) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File does not exist: $filePath');
      }

      final fileSize = await file.length();
      final fileName = file.path.split('/').last;
      
      final transferId = '${DateTime.now().millisecondsSinceEpoch}_${device.deviceId}';
      final transferInfo = TransferInfo(
        id: transferId,
        fileName: fileName,
        fileSize: fileSize,
        filePath: filePath,
        type: TransferType.sending,
        status: TransferStatus.pending,
        startTime: DateTime.now(),
      );

      _activeTransfers[transferId] = transferInfo;
      _transferController.add(transferInfo);

      // Update status to in progress
      final updatedTransfer = transferInfo.copyWith(
        status: TransferStatus.inProgress,
        progress: 0.0,
      );
      _activeTransfers[transferId] = updatedTransfer;
      _transferController.add(updatedTransfer);

      // Simulate progress updates
      for (int i = 0; i <= 100; i += 10) {
        await Future.delayed(const Duration(milliseconds: 200));
        
        final progressTransfer = _activeTransfers[transferId]?.copyWith(
          progress: i / 100.0,
        );
        
        if (progressTransfer != null) {
          _activeTransfers[transferId] = progressTransfer;
          _transferController.add(progressTransfer);
        }
      }

      // Mark as completed
      final completedTransfer = transferInfo.copyWith(
        status: TransferStatus.completed,
        progress: 1.0,
        endTime: DateTime.now(),
      );
      _activeTransfers[transferId] = completedTransfer;
      _transferController.add(completedTransfer);
      _completedTransferController.add(completedTransfer);

      return completedTransfer;
    } catch (e) {
      final transferId = '${DateTime.now().millisecondsSinceEpoch}_${device.deviceId}';
      final failedTransfer = TransferInfo(
        id: transferId,
        fileName: filePath.split('/').last,
        fileSize: 0,
        filePath: filePath,
        type: TransferType.sending,
        status: TransferStatus.failed,
        errorMessage: e.toString(),
        startTime: DateTime.now(),
        endTime: DateTime.now(),
      );
      
      _activeTransfers[transferId] = failedTransfer;
      _transferController.add(failedTransfer);
      
      return failedTransfer;
    }
  }

  Future<void> simulateIncomingFile(String fileName, int fileSize) async {
    final transferId = 'incoming_${DateTime.now().millisecondsSinceEpoch}';
    final transferInfo = TransferInfo(
      id: transferId,
      fileName: fileName,
      fileSize: fileSize,
      type: TransferType.receiving,
      status: TransferStatus.pending,
      startTime: DateTime.now(),
    );

    _activeTransfers[transferId] = transferInfo;
    _transferController.add(transferInfo);

    // Simulate receiving progress
    final updatedTransfer = transferInfo.copyWith(
      status: TransferStatus.inProgress,
      progress: 0.0,
    );
    _activeTransfers[transferId] = updatedTransfer;
    _transferController.add(updatedTransfer);

    // Simulate progress updates
    for (int i = 0; i <= 100; i += 15) {
      await Future.delayed(const Duration(milliseconds: 300));
      
      final progressTransfer = _activeTransfers[transferId]?.copyWith(
        progress: i / 100.0,
      );
      
      if (progressTransfer != null) {
        _activeTransfers[transferId] = progressTransfer;
        _transferController.add(progressTransfer);
      }
    }

    // Save mock file
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      
      // Create a mock file with some content
      await file.writeAsString('Mock file content for $fileName');
      
      // Mark as completed
      final completedTransfer = transferInfo.copyWith(
        status: TransferStatus.completed,
        progress: 1.0,
        filePath: filePath,
        endTime: DateTime.now(),
      );
      _activeTransfers[transferId] = completedTransfer;
      _transferController.add(completedTransfer);
      _completedTransferController.add(completedTransfer);

      // Open the file
      await OpenFilex.open(filePath);
    } catch (e) {
      final failedTransfer = transferInfo.copyWith(
        status: TransferStatus.failed,
        errorMessage: e.toString(),
        endTime: DateTime.now(),
      );
      _activeTransfers[transferId] = failedTransfer;
      _transferController.add(failedTransfer);
    }
  }

  List<TransferInfo> getActiveTransfers() {
    return _activeTransfers.values.toList();
  }

  TransferInfo? getTransferById(String id) {
    return _activeTransfers[id];
  }

  Future<void> dispose() async {
    await _transferController.close();
    await _completedTransferController.close();
    _activeTransfers.clear();
  }
}
