import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/device_info.dart';

class MockDeviceService {
  static final MockDeviceService _instance = MockDeviceService._internal();
  factory MockDeviceService() => _instance;
  MockDeviceService._internal();

  final StreamController<List<DeviceInfo>> _devicesController = 
      StreamController<List<DeviceInfo>>.broadcast();
  final StreamController<DeviceInfo> _connectionController = 
      StreamController<DeviceInfo>.broadcast();

  Stream<List<DeviceInfo>> get devicesStream => _devicesController.stream;
  Stream<DeviceInfo> get connectionStream => _connectionController.stream;

  List<DeviceInfo> _devices = [];
  bool _isInitialized = false;
  Timer? _discoveryTimer;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Simulate device discovery
    _simulateDeviceDiscovery();
    
    _isInitialized = true;
  }

  void _simulateDeviceDiscovery() {
    // Add some mock devices
    final mockDevices = [
      DeviceInfo(
        deviceId: 'device_001',
        deviceName: 'Samsung Galaxy S21',
        endpointId: 'device_001',
      ),
      DeviceInfo(
        deviceId: 'device_002', 
        deviceName: 'iPhone 13 Pro',
        endpointId: 'device_002',
      ),
      DeviceInfo(
        deviceId: 'device_003',
        deviceName: 'Pixel 6',
        endpointId: 'device_003',
      ),
    ];

    _devices.addAll(mockDevices);
    _devicesController.add(List.from(_devices));

    // Simulate periodic device updates
    _discoveryTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_devices.isNotEmpty) {
        final random = Random();
        final deviceIndex = random.nextInt(_devices.length);
        final device = _devices[deviceIndex];
        
        // Simulate connection state changes
        if (random.nextBool()) {
          _devices[deviceIndex] = device.copyWith(
            isConnected: !device.isConnected,
            isConnecting: false,
          );
          _devicesController.add(List.from(_devices));
          _connectionController.add(_devices[deviceIndex]);
        }
      }
    });
  }

  Future<bool> connectToDevice(DeviceInfo device) async {
    try {
      // Update device state to connecting
      final deviceIndex = _devices.indexWhere((d) => d.deviceId == device.deviceId);
      if (deviceIndex != -1) {
        _devices[deviceIndex] = _devices[deviceIndex].copyWith(isConnecting: true);
        _devicesController.add(List.from(_devices));
      }

      // Simulate connection delay
      await Future.delayed(const Duration(seconds: 2));

      // Mark as connected
      if (deviceIndex != -1) {
        _devices[deviceIndex] = _devices[deviceIndex].copyWith(
          isConnected: true,
          isConnecting: false,
        );
        _devicesController.add(List.from(_devices));
        _connectionController.add(_devices[deviceIndex]);
      }

      return true;
    } catch (e) {
      print('Error connecting to device: $e');
      return false;
    }
  }

  Future<bool> disconnectFromDevice(DeviceInfo device) async {
    try {
      final deviceIndex = _devices.indexWhere((d) => d.deviceId == device.deviceId);
      if (deviceIndex != -1) {
        _devices[deviceIndex] = _devices[deviceIndex].copyWith(
          isConnected: false,
          isConnecting: false,
        );
        _devicesController.add(List.from(_devices));
        _connectionController.add(_devices[deviceIndex]);
      }
      return true;
    } catch (e) {
      print('Error disconnecting from device: $e');
      return false;
    }
  }

  List<DeviceInfo> getConnectedDevices() {
    return _devices.where((d) => d.isConnected).toList();
  }

  Future<void> dispose() async {
    _discoveryTimer?.cancel();
    await _devicesController.close();
    await _connectionController.close();
    _isInitialized = false;
  }
}
