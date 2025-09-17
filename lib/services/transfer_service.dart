import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../models/transfer_info.dart';
import '../models/device_info.dart';
import 'device_service.dart';

class TransferService {
  static final TransferService _instance = TransferService._internal();
  factory TransferService() => _instance;
  TransferService._internal();

  final StreamController<TransferInfo> _transferController = 
      StreamController<TransferInfo>.broadcast();
  final StreamController<TransferInfo> _completedTransferController = 
      StreamController<TransferInfo>.broadcast();

  Stream<TransferInfo> get transferStream => _transferController.stream;
  Stream<TransferInfo> get completedTransferStream => _completedTransferController.stream;

  final Map<String, TransferInfo> _activeTransfers = {};
  final DeviceService _deviceService = DeviceService();

  void initialize() {
    // Mock implementation for demo
    print('Using mock transfer service for demo');
  }

  Future<TransferInfo?> sendFile(String filePath, DeviceInfo device) async {
    // Mock implementation - always return null to trigger fallback
    return null;
  }


  // Mock methods for demo
  Future<void> handleIncomingData(String endpointId, Uint8List data) async {
    // Mock implementation
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
