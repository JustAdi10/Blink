import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/device_info.dart';

class RealDeviceService {
  static final RealDeviceService _instance = RealDeviceService._internal();
  factory RealDeviceService() => _instance;
  RealDeviceService._internal();

  final StreamController<List<DeviceInfo>> _devicesController = 
      StreamController<List<DeviceInfo>>.broadcast();
  final StreamController<DeviceInfo> _connectionController = 
      StreamController<DeviceInfo>.broadcast();

  Stream<List<DeviceInfo>> get devicesStream => _devicesController.stream;
  Stream<DeviceInfo> get connectionStream => _connectionController.stream;

  List<DeviceInfo> _devices = [];
  bool _isInitialized = false;
  bool _isAdvertising = false;
  bool _isDiscovering = false;
  final Nearby _nearby = Nearby();
  final Map<String, Map<String, dynamic>> _pendingFileMetadata = {};
  String _currentDeviceName = 'Blink Device';

  Future<void> initialize() async {
    if (_isInitialized) return;

    if (kIsWeb) {
      print('nearby_connections is not supported on web platform');
      _isInitialized = true;
      return;
    }

    try {
      // Load device name
      await _loadDeviceName();
      
      // Request necessary permissions
      await _requestPermissions();
      
      // Add delay to prevent conflicts
      await Future.delayed(const Duration(milliseconds: 500));
      
      await _startAdvertising();
      
      // Add delay between advertising and discovery
      await Future.delayed(const Duration(milliseconds: 500));
      
      await _startDiscovery();
      
      // Start connection health check
      _startConnectionHealthCheck();
      
      _isInitialized = true;
      print('Real device service initialized successfully');
    } catch (e) {
      print('Error initializing real device service: $e');
      // Don't rethrow, allow fallback to mock services
    }
  }

  Future<void> _loadDeviceName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString('device_name');
      if (savedName != null && savedName.isNotEmpty) {
        _currentDeviceName = savedName;
        print('Loaded device name: $_currentDeviceName');
      }
    } catch (e) {
      print('Error loading device name: $e');
    }
  }

  Future<void> updateDeviceName(String newName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('device_name', newName);
      _currentDeviceName = newName;
      print('Updated device name to: $_currentDeviceName');
      
      // Restart advertising with new name if already initialized
      if (_isInitialized && _isAdvertising) {
        await _nearby.stopAdvertising();
        _isAdvertising = false;
        await Future.delayed(const Duration(milliseconds: 500));
        await _startAdvertising();
      }
    } catch (e) {
      print('Error updating device name: $e');
    }
  }

  Future<void> _requestPermissions() async {
    if (kIsWeb) {
      // Skip permissions on web
      return;
    }
    
    // Get Android version to determine which permissions to request
    int? androidApiLevel;
    if (Platform.isAndroid) {
      try {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        androidApiLevel = androidInfo.version.sdkInt;
        print('Android API Level: $androidApiLevel');
      } catch (e) {
        print('Error detecting Android version: $e');
      }
    }
    
    // Request permissions based on Android version
    final List<Permission> permissionsToRequest = [
      Permission.location,
      Permission.bluetooth,
    ];
    
    // Add version-specific permissions
    if (Platform.isAndroid) {
      if (androidApiLevel != null && androidApiLevel >= 31) {
        // Android 12+ requires new Bluetooth permissions
        permissionsToRequest.addAll([
          Permission.bluetoothAdvertise,
          Permission.bluetoothConnect,
          Permission.bluetoothScan,
        ]);
      }
      
      if (androidApiLevel != null && androidApiLevel >= 33) {
        // Android 13+ requires nearby WiFi devices permission
        permissionsToRequest.add(Permission.nearbyWifiDevices);
      }
      
      // Add storage permissions based on Android version
      if (androidApiLevel != null && androidApiLevel >= 33) {
        // Android 13+ uses granular media permissions
        permissionsToRequest.addAll([
          Permission.photos,
          Permission.videos,
          Permission.audio,
        ]);
      } else {
        // Android 11-12 uses legacy storage permissions
        permissionsToRequest.add(Permission.storage);
      }
    }
    
    final Map<Permission, PermissionStatus> statuses = await permissionsToRequest.request();

    // Check critical permissions
    if (statuses[Permission.location] != PermissionStatus.granted) {
      throw Exception('Location permission is required for nearby connections');
    }

    if (statuses[Permission.bluetooth] != PermissionStatus.granted) {
      throw Exception('Bluetooth permission is required for nearby connections');
    }

    // Check Android 12+ Bluetooth permissions (only if Android 12+)
    if (androidApiLevel != null && androidApiLevel >= 31) {
      if (statuses[Permission.bluetoothAdvertise] != PermissionStatus.granted ||
          statuses[Permission.bluetoothConnect] != PermissionStatus.granted ||
          statuses[Permission.bluetoothScan] != PermissionStatus.granted) {
        print('Some Bluetooth permissions denied (Android 12+), but continuing...');
      }
    }

    // Check storage permissions based on Android version
    if (!kIsWeb && Platform.isAndroid) {
      if (androidApiLevel != null && androidApiLevel >= 33) {
        // Android 13+ uses granular media permissions
        if (statuses[Permission.photos] != PermissionStatus.granted ||
            statuses[Permission.videos] != PermissionStatus.granted ||
            statuses[Permission.audio] != PermissionStatus.granted) {
          print('Some media permissions denied (Android 13+), file transfers may be limited');
        }
      } else {
        // Android 11-12 uses legacy storage permissions
        if (statuses[Permission.storage] != PermissionStatus.granted) {
          print('Storage permission denied (Android 11-12), file transfers may not work');
        }
      }
    }

    // Nearby WiFi devices permission (Android 13+)
    if (androidApiLevel != null && androidApiLevel >= 33) {
      if (statuses[Permission.nearbyWifiDevices] != PermissionStatus.granted) {
        print('Nearby WiFi devices permission denied (Android 13+), but continuing...');
      }
    }
  }

  Future<void> _startAdvertising() async {
    if (_isAdvertising) return;
    
    try {
      print('Starting advertising with name: $_currentDeviceName');
      await _nearby.startAdvertising(
        _currentDeviceName,
        Strategy.P2P_STAR,
        onConnectionInitiated: (String endpointId, ConnectionInfo connectionInfo) {
          print('Advertising - Connection initiated: $endpointId');
          _handleConnectionInitiated(endpointId, connectionInfo.endpointName, true);
          
          // Accept incoming connections immediately without delay
          _acceptConnection(endpointId);
        },
        onConnectionResult: (String endpointId, Status status) {
          print('Advertising - Connection result: $endpointId, $status');
          _handleConnectionResult(endpointId, status);
        },
        onDisconnected: (String endpointId) {
          print('Advertising - Disconnected: $endpointId');
          _handleDisconnected(endpointId);
        },
        serviceId: 'blink_share',
      );
      _isAdvertising = true;
      print('Advertising started successfully');
    } catch (e) {
      print('Error starting advertising: $e');
      // Check if it's already advertising error
      if (e.toString().contains('STATUS_ALREADY_ADVERTISING')) {
        _isAdvertising = true;
        print('Already advertising, continuing...');
      }
    }
  }

  Future<void> _startDiscovery() async {
    if (_isDiscovering) return;
    
    try {
      await _nearby.startDiscovery(
        _currentDeviceName,
        Strategy.P2P_STAR,
        onEndpointFound: (String endpointId, String endpointName, String serviceId) {
          print('Discovery - Endpoint found: $endpointId, $endpointName');
          _handleEndpointFound(endpointId, endpointName);
        },
        onEndpointLost: (String? endpointId) {
          print('Discovery - Endpoint lost: $endpointId');
          _handleEndpointLost(endpointId);
        },
        serviceId: 'blink_share',
      );
      _isDiscovering = true;
      print('Discovery started successfully');
    } catch (e) {
      print('Error starting discovery: $e');
      // Check if it's already discovering error
      if (e.toString().contains('STATUS_ALREADY_DISCOVERING')) {
        _isDiscovering = true;
        print('Already discovering, continuing...');
      }
    }
  }

  void _handleEndpointFound(String endpointId, String endpointName) {
    print('Endpoint found - ID: $endpointId, Name: $endpointName');
    
    final deviceInfo = DeviceInfo(
      deviceId: endpointId,
      deviceName: endpointName,
      endpointId: endpointId,
    );
    
    // Check if device already exists
    final existingIndex = _devices.indexWhere((d) => d.deviceId == endpointId);
    if (existingIndex == -1) {
      _devices.add(deviceInfo);
      _devicesController.add(List.from(_devices));
      print('Device added: $endpointName ($endpointId)');
    } else {
      // Update existing device
      _devices[existingIndex] = deviceInfo;
      _devicesController.add(List.from(_devices));
      print('Device updated: $endpointName ($endpointId)');
    }
  }

  void _handleEndpointLost(String? endpointId) {
    if (endpointId != null) {
      print('Endpoint lost: $endpointId');
      _devices.removeWhere((d) => d.endpointId == endpointId);
      _devicesController.add(List.from(_devices));
    }
  }

  void _handleConnectionInitiated(String endpointId, String endpointName, bool isIncoming) {
    print('Connection initiated: $endpointId, $endpointName, isIncoming: $isIncoming');
    final deviceIndex = _devices.indexWhere((d) => d.endpointId == endpointId);
    if (deviceIndex != -1) {
      _devices[deviceIndex] = _devices[deviceIndex].copyWith(isConnecting: true);
      _devicesController.add(List.from(_devices));
      print('Updated device ${_devices[deviceIndex].deviceName} to connecting');
    } else {
      print('No device found with endpointId for connection initiation: $endpointId');
    }
  }

  void _handleConnectionResult(String endpointId, Status status) {
    print('Connection result for $endpointId: $status');
    final deviceIndex = _devices.indexWhere((d) => d.endpointId == endpointId);
    if (deviceIndex != -1) {
      final isConnected = status == Status.CONNECTED;
      _devices[deviceIndex] = _devices[deviceIndex].copyWith(
        isConnected: isConnected,
        isConnecting: false,
      );
      _devicesController.add(List.from(_devices));
      _connectionController.add(_devices[deviceIndex]);
      print('Updated device ${_devices[deviceIndex].deviceName} connection status: $isConnected');
      
      // If connection failed, try to reconnect after a delay
      if (!isConnected && status != Status.CONNECTED) {
        print('Connection failed, will retry in 2 seconds...');
        Future.delayed(const Duration(seconds: 2), () {
          _retryConnection(_devices[deviceIndex]);
        });
      }
    } else {
      print('No device found with endpointId: $endpointId');
    }
  }

  void _handleDisconnected(String endpointId) {
    print('Device disconnected: $endpointId');
    final deviceIndex = _devices.indexWhere((d) => d.endpointId == endpointId);
    if (deviceIndex != -1) {
      _devices[deviceIndex] = _devices[deviceIndex].copyWith(
        isConnected: false,
        isConnecting: false,
      );
      _devicesController.add(List.from(_devices));
      _connectionController.add(_devices[deviceIndex]);
      print('Updated device ${_devices[deviceIndex].deviceName} to disconnected');
      
      // Try to reconnect after disconnection
      print('Attempting to reconnect to ${_devices[deviceIndex].deviceName}...');
      Future.delayed(const Duration(seconds: 1), () {
        _retryConnection(_devices[deviceIndex]);
      });
    } else {
      print('No device found with endpointId for disconnect: $endpointId');
    }
  }

  Future<void> _retryConnection(DeviceInfo device) async {
    try {
      print('Retrying connection to ${device.deviceName}...');
      await connectToDevice(device);
    } catch (e) {
      print('Retry connection failed: $e');
    }
  }

  void _startConnectionHealthCheck() {
    // Check connection health every 5 seconds
    Timer.periodic(const Duration(seconds: 5), (timer) {
      for (final device in _devices) {
        if (device.isConnected) {
          print('Health check: ${device.deviceName} is connected');
        } else if (device.isConnecting) {
          print('Health check: ${device.deviceName} is still connecting...');
        } else {
          print('Health check: ${device.deviceName} is disconnected, attempting reconnect...');
          _retryConnection(device);
        }
      }
    });
  }

  Future<bool> connectToDevice(DeviceInfo device) async {
    try {
      // Check if already connected
      final deviceIndex = _devices.indexWhere((d) => d.deviceId == device.deviceId);
      if (deviceIndex != -1 && _devices[deviceIndex].isConnected) {
        print('Device ${device.deviceName} is already connected');
        return true;
      }

      // Update device state to connecting
      if (deviceIndex != -1) {
        _devices[deviceIndex] = _devices[deviceIndex].copyWith(isConnecting: true);
        _devicesController.add(List.from(_devices));
      }

      // Request connection
      final success = await _nearby.requestConnection(
        _currentDeviceName,
        device.endpointId,
        onConnectionInitiated: (String endpointId, ConnectionInfo connectionInfo) {
          print('Request - Connection initiated: $endpointId');
          _handleConnectionInitiated(endpointId, connectionInfo.endpointName, false);
          
          // Don't accept connection from request side - let the advertising side handle it
        },
        onConnectionResult: (String endpointId, Status status) {
          print('Request - Connection result: $endpointId, $status');
          _handleConnectionResult(endpointId, status);
        },
        onDisconnected: (String endpointId) {
          print('Request - Disconnected: $endpointId');
          _handleDisconnected(endpointId);
        },
      );
      
      return success;
    } catch (e) {
      print('Error connecting to device: $e');
      // Reset connecting state on error
      final deviceIndex = _devices.indexWhere((d) => d.deviceId == device.deviceId);
      if (deviceIndex != -1) {
        _devices[deviceIndex] = _devices[deviceIndex].copyWith(isConnecting: false);
        _devicesController.add(List.from(_devices));
      }
      return false;
    }
  }

  Future<void> _acceptConnection(String endpointId) async {
    try {
      // Validate endpointId before accepting
      if (endpointId.isEmpty) {
        print('Cannot accept connection: endpointId is empty');
        return;
      }
      
      print('Accepting connection from: $endpointId');
      await _nearby.acceptConnection(
        endpointId,
        onPayLoadRecieved: (String endpointId, Payload payload) async {
          print('Payload received from $endpointId: ${payload.bytes?.length ?? 0} bytes, type: ${payload.type}');
          // Handle payload in transfer service
          await _handleIncomingPayload(endpointId, payload);
        },
      );
      print('Connection accepted successfully: $endpointId');
      
      // Update device state to connected after successful acceptance
      final deviceIndex = _devices.indexWhere((d) => d.endpointId == endpointId);
      if (deviceIndex != -1) {
        _devices[deviceIndex] = _devices[deviceIndex].copyWith(
          isConnected: true,
          isConnecting: false,
        );
        _devicesController.add(List.from(_devices));
        print('Updated device ${_devices[deviceIndex].deviceName} to connected after acceptance');
      }
    } catch (e) {
      print('Error accepting connection: $e');
    }
  }

  Future<void> _handleIncomingPayload(String endpointId, Payload payload) async {
    try {
      if (payload.type == PayloadType.BYTES) {
        final dataString = String.fromCharCodes(payload.bytes ?? Uint8List(0));
        print('Received bytes payload: $dataString');
        
        // Check if it's metadata
        if (dataString.contains('file_metadata')) {
          await _handleFileMetadata(endpointId, dataString);
        } else {
          // This might be file data, check if we have pending metadata
          final metadata = _pendingFileMetadata.values
              .where((m) => m['endpointId'] == endpointId)
              .firstOrNull;
          
          if (metadata != null) {
            final fileName = metadata['fileName'] as String;
            print('Received file bytes for: $fileName');
            await _handleFileBytes(endpointId, payload.bytes!, fileName);
            
            // Clean up metadata
            final transferId = metadata['transferId'] as String;
            _pendingFileMetadata.remove(transferId);
          } else {
            print('Received bytes but no pending metadata found');
          }
        }
      } else if (payload.type == PayloadType.FILE) {
        print('Received file payload: ${payload.filePath}');
        await _handleFilePayload(endpointId, payload);
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

    print('File metadata received: $fileName ($fileSize bytes)');
    
    // Store metadata for when file payload arrives
    _pendingFileMetadata[transferId] = {
      'fileName': fileName,
      'fileSize': fileSize,
      'transferId': transferId,
      'endpointId': endpointId,
    };
  }

  Future<void> _handleFilePayload(String endpointId, Payload payload) async {
    try {
      // Find corresponding metadata
      final metadata = _pendingFileMetadata.values
          .where((m) => m['endpointId'] == endpointId)
          .firstOrNull;
      
      if (metadata == null) {
        print('No metadata found for file payload from $endpointId');
        return;
      }

      final fileName = metadata['fileName'] as String;
      final transferId = metadata['transferId'] as String;
      
      print('Handling file payload: fileName=$fileName, payload.filePath=${payload.filePath}');
      
      // Check if we have a valid file path from the payload
      if (payload.filePath == null || payload.filePath!.isEmpty) {
        print('Invalid file path in payload, trying to handle as bytes');
        // Try to handle as bytes if file path is not available
        if (payload.bytes != null && payload.bytes!.isNotEmpty) {
          await _handleFileBytes(endpointId, payload.bytes!, fileName);
        } else {
          print('No file path or bytes available in payload');
        }
        return;
      }
      
      // Get downloads directory
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName';
      
      print('Saving file to: $filePath');
      
      // Copy the received file to our directory
      final sourceFile = File(payload.filePath!);
      final targetFile = File(filePath);
      
      // Check if source file exists
      if (!await sourceFile.exists()) {
        print('Source file does not exist: ${payload.filePath}');
        return;
      }
      
      await sourceFile.copy(filePath);
      
      print('File saved successfully: $fileName');
      
      // Clean up metadata
      _pendingFileMetadata.remove(transferId);
      
      // Open the file
      await OpenFilex.open(filePath);
    } catch (e) {
      print('Error handling file payload: $e');
    }
  }

  Future<void> _handleFileBytes(String endpointId, Uint8List bytes, String fileName) async {
    try {
      // Check if fileName is empty or null
      if (fileName.isEmpty) {
        print('FileName is empty, using default name');
        fileName = 'received_file_${DateTime.now().millisecondsSinceEpoch}';
      }
      
      // Get downloads directory
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName';
      
      print('Saving file bytes to: $filePath');
      
      // Write bytes directly to file
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      
      print('File bytes saved successfully: $fileName');
      
      // Open the file
      await OpenFilex.open(filePath);
    } catch (e) {
      print('Error handling file bytes: $e');
    }
  }

  String _extractValue(String data, String key) {
    // Try different patterns to extract values
    final patterns = [
      RegExp('$key\':\\s*([^,}]+)'),
      RegExp('$key: ([^,}]+)'),
      RegExp('"$key": "([^"]+)"'),
      RegExp("'$key': '([^']+)'"),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(data);
      if (match != null && match.group(1) != null) {
        return match.group(1)!.trim().replaceAll("'", '').replaceAll('"', '');
      }
    }
    
    print('Could not extract $key from: $data');
    return '';
  }

  Future<bool> disconnectFromDevice(DeviceInfo device) async {
    try {
      await _nearby.disconnectFromEndpoint(device.endpointId);
      
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

  Nearby get nearby => _nearby;

  Future<void> dispose() async {
    if (_isAdvertising) {
      await _nearby.stopAdvertising();
    }
    if (_isDiscovering) {
      await _nearby.stopDiscovery();
    }
    await _devicesController.close();
    await _connectionController.close();
    _isInitialized = false;
  }
}