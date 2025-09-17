import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../models/transfer_info.dart';
import '../models/device_info.dart';
import 'real_device_service.dart';

class RealTransferService {
  static final RealTransferService _instance = RealTransferService._internal();
  factory RealTransferService() => _instance;
  RealTransferService._internal();

  final StreamController<TransferInfo> _transferController = 
      StreamController<TransferInfo>.broadcast();
  final StreamController<TransferInfo> _completedTransferController = 
      StreamController<TransferInfo>.broadcast();

  Stream<TransferInfo> get transferStream => _transferController.stream;
  Stream<TransferInfo> get completedTransferStream => _completedTransferController.stream;

  final Map<String, TransferInfo> _activeTransfers = {};
  final RealDeviceService _deviceService = RealDeviceService();
  final Nearby _nearby = Nearby();

  void initialize() {
    // Payload handling is now done in the device service
    // when connections are accepted
    print('Real transfer service initialized');
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

      // Send file metadata first
      final metadata = {
        'type': 'file_metadata',
        'fileName': fileName,
        'fileSize': fileSize,
        'transferId': transferId,
      };

      final metadataString = metadata.toString();
      final metadataBytes = Uint8List.fromList(metadataString.codeUnits);
      
      print('Sending metadata: $metadataString');
      await _nearby.sendBytesPayload(device.endpointId, metadataBytes);

        // Send the actual file as bytes for better compatibility
        print('Sending file: $fileName (${fileSize} bytes)');
        
        // Read file as bytes and send in chunks
        final fileBytes = await file.readAsBytes();
        await _nearby.sendBytesPayload(device.endpointId, fileBytes);

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

  Future<void> handleIncomingPayload(String endpointId, Payload payload) async {
    try {
      if (payload.type == PayloadType.BYTES) {
        final dataString = String.fromCharCodes(payload.bytes ?? Uint8List(0));
        
        // Check if it's metadata
        if (dataString.contains('file_metadata')) {
          await _handleFileMetadata(endpointId, dataString);
        } else {
          // It's actual file data
          await _handleFileData(endpointId, payload.bytes ?? Uint8List(0));
        }
      }
    } catch (e) {
      print('Error handling incoming payload: $e');
    }
  }

  Future<void> _handleFileMetadata(String endpointId, String metadataString) async {
    // Parse metadata (simplified parsing)
    final fileName = _extractValue(metadataString, 'fileName');
    final fileSize = int.tryParse(_extractValue(metadataString, 'fileSize')) ?? 0;
    final transferId = _extractValue(metadataString, 'transferId');

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
  }

  Future<void> _handleFileData(String endpointId, Uint8List data) async {
    // Find the corresponding transfer
    final transfer = _activeTransfers.values
        .where((t) => t.type == TransferType.receiving && t.status == TransferStatus.pending)
        .firstOrNull;

    if (transfer == null) return;

    try {
      // Update status to in progress
      final updatedTransfer = transfer.copyWith(
        status: TransferStatus.inProgress,
        progress: 0.0,
      );
      _activeTransfers[transfer.id] = updatedTransfer;
      _transferController.add(updatedTransfer);

      // Save file
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/${transfer.fileName}';
      final file = File(filePath);
      
      await file.writeAsBytes(data);

      // Mark as completed
      final completedTransfer = transfer.copyWith(
        status: TransferStatus.completed,
        progress: 1.0,
        filePath: filePath,
        endTime: DateTime.now(),
      );
      _activeTransfers[transfer.id] = completedTransfer;
      _transferController.add(completedTransfer);
      _completedTransferController.add(completedTransfer);

      // Open the file
      await OpenFilex.open(filePath);
    } catch (e) {
      final failedTransfer = transfer.copyWith(
        status: TransferStatus.failed,
        errorMessage: e.toString(),
        endTime: DateTime.now(),
      );
      _activeTransfers[transfer.id] = failedTransfer;
      _transferController.add(failedTransfer);
    }
  }

  String _extractValue(String data, String key) {
    final regex = RegExp('$key\':\\s*([^,}]+)');
    final match = regex.firstMatch(data);
    return match?.group(1)?.trim().replaceAll("'", '') ?? '';
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