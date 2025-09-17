import 'dart:async';
import 'package:flutter/foundation.dart';
// import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';
import '../models/device_info.dart';

class DeviceService {
  static final DeviceService _instance = DeviceService._internal();
  factory DeviceService() => _instance;
  DeviceService._internal();

  // NearbyService? _nearbyService;
  final StreamController<List<DeviceInfo>> _devicesController = 
      StreamController<List<DeviceInfo>>.broadcast();
  final StreamController<DeviceInfo> _connectionController = 
      StreamController<DeviceInfo>.broadcast();

  Stream<List<DeviceInfo>> get devicesStream => _devicesController.stream;
  Stream<DeviceInfo> get connectionStream => _connectionController.stream;

  List<DeviceInfo> _devices = [];
  bool _isInitialized = false;
  
  // Make nearby service accessible to other services
  // NearbyService? get nearbyService => _nearbyService;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // For demo purposes, always use mock services
    print('Using mock device service for demo');
    _isInitialized = true;
  }

  Future<bool> connectToDevice(DeviceInfo device) async {
    // Mock implementation - always return false to trigger fallback
    return false;
  }

  Future<bool> disconnectFromDevice(DeviceInfo device) async {
    // Mock implementation - always return false to trigger fallback
    return false;
  }

  List<DeviceInfo> getConnectedDevices() {
    return _devices.where((d) => d.isConnected).toList();
  }

  Future<void> dispose() async {
    await _devicesController.close();
    await _connectionController.close();
    _isInitialized = false;
  }
}
