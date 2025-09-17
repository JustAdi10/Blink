import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/device_service.dart';
import '../services/transfer_service.dart';
import '../services/mock_device_service.dart';
import '../services/mock_transfer_service.dart';
import '../models/device_info.dart';
import '../models/transfer_info.dart';
import '../widgets/device_tile.dart';
import '../widgets/progress_bar.dart';
import 'transfer_progress_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DeviceService _deviceService = DeviceService();
  final TransferService _transferService = TransferService();
  final MockDeviceService _mockDeviceService = MockDeviceService();
  final MockTransferService _mockTransferService = MockTransferService();
  
  List<DeviceInfo> _devices = [];
  List<TransferInfo> _activeTransfers = [];
  bool _isInitialized = false;
  bool _isLoading = false;

  StreamSubscription<List<DeviceInfo>>? _devicesSubscription;
  StreamSubscription<TransferInfo>? _transferSubscription;
  StreamSubscription<TransferInfo>? _completedTransferSubscription;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Try to initialize real services first
      await _deviceService.initialize();
      _transferService.initialize();
      
      _devicesSubscription = _deviceService.devicesStream.listen((devices) {
        setState(() {
          _devices = devices;
        });
      });

      _transferSubscription = _transferService.transferStream.listen((transfer) {
        setState(() {
          _activeTransfers = _transferService.getActiveTransfers();
        });
      });

      _completedTransferSubscription = _transferService.completedTransferStream.listen((transfer) {
        _showTransferCompletedSnackBar(transfer);
      });

      setState(() {
        _isInitialized = true;
        _isLoading = false;
      });
    } catch (e) {
      print('Real services failed, falling back to mock services: $e');
      
      // Fallback to mock services
      await _mockDeviceService.initialize();
      _mockTransferService.initialize();
      
      _devicesSubscription = _mockDeviceService.devicesStream.listen((devices) {
        setState(() {
          _devices = devices;
        });
      });

      _transferSubscription = _mockTransferService.transferStream.listen((transfer) {
        setState(() {
          _activeTransfers = _mockTransferService.getActiveTransfers();
        });
      });

      _completedTransferSubscription = _mockTransferService.completedTransferStream.listen((transfer) {
        _showTransferCompletedSnackBar(transfer);
      });

      setState(() {
        _isInitialized = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _connectToDevice(DeviceInfo device) async {
    bool success;
    if (_isInitialized && _devices.isNotEmpty) {
      // Use mock service if we have mock devices
      success = await _mockDeviceService.connectToDevice(device);
    } else {
      success = await _deviceService.connectToDevice(device);
    }
    
    if (!success) {
      _showErrorSnackBar('Failed to connect to ${device.deviceName}');
    }
  }

  Future<void> _disconnectFromDevice(DeviceInfo device) async {
    bool success;
    if (_isInitialized && _devices.isNotEmpty) {
      // Use mock service if we have mock devices
      success = await _mockDeviceService.disconnectFromDevice(device);
    } else {
      success = await _deviceService.disconnectFromDevice(device);
    }
    
    if (!success) {
      _showErrorSnackBar('Failed to disconnect from ${device.deviceName}');
    }
  }

  Future<void> _selectAndSendFile(DeviceInfo device) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null) {
          TransferInfo? transfer;
          if (_isInitialized && _devices.isNotEmpty) {
            // Use mock service if we have mock devices
            transfer = await _mockTransferService.sendFile(file.path!, device);
          } else {
            transfer = await _transferService.sendFile(file.path!, device);
          }
          
          if (transfer != null) {
            _navigateToTransferProgress();
          }
        }
      }
    } catch (e) {
      _showErrorSnackBar('Failed to select file: $e');
    }
  }

  void _navigateToTransferProgress() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const TransferProgressScreen(),
      ),
    );
  }

  void _showTransferCompletedSnackBar(TransferInfo transfer) {
    final message = transfer.status == TransferStatus.completed
        ? '${transfer.fileName} ${transfer.type == TransferType.sending ? 'sent' : 'received'} successfully!'
        : 'Transfer failed: ${transfer.errorMessage}';
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: transfer.status == TransferStatus.completed
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.error,
        action: transfer.status == TransferStatus.completed && transfer.filePath != null
            ? SnackBarAction(
                label: 'Open',
                onPressed: () {
                  // File will be opened automatically by TransferService
                },
              )
            : null,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  void dispose() {
    _devicesSubscription?.cancel();
    _transferSubscription?.cancel();
    _completedTransferSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Blink'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        actions: [
          IconButton(
            onPressed: _isInitialized ? _navigateToTransferProgress : null,
            icon: const Icon(Icons.history),
            tooltip: 'Transfer History',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !_isInitialized
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64.0,
                        color: colorScheme.error,
                      ),
                      const SizedBox(height: 16.0),
                      Text(
                        'Failed to initialize',
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8.0),
                      ElevatedButton(
                        onPressed: _initializeServices,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Status section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16.0),
                      color: colorScheme.surfaceVariant.withOpacity(0.3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nearby Devices',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4.0),
                          Text(
                            '${_devices.length} devices found',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Active transfers section
                    if (_activeTransfers.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16.0),
                        color: colorScheme.primaryContainer.withOpacity(0.3),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Active Transfers',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8.0),
                            ..._activeTransfers.map((transfer) => 
                              TransferProgressCard(transferInfo: transfer)
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    // Devices list
                    Expanded(
                      child: kIsWeb
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.web,
                                    size: 64.0,
                                    color: colorScheme.outline,
                                  ),
                                  const SizedBox(height: 16.0),
                                  Text(
                                    'Web Platform Not Supported',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 8.0),
                                  Text(
                                    'Blink requires mobile devices (iOS/Android)\nfor peer-to-peer file sharing',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : _devices.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.device_unknown,
                                        size: 64.0,
                                        color: colorScheme.outline,
                                      ),
                                      const SizedBox(height: 16.0),
                                      Text(
                                        'No devices found',
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(height: 8.0),
                                      Text(
                                        'Make sure other devices are running Blink',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                          : ListView.builder(
                              itemCount: _devices.length,
                              itemBuilder: (context, index) {
                                final device = _devices[index];
                                return DeviceListTile(
                                  device: device,
                                  onConnect: () => _connectToDevice(device),
                                  onDisconnect: () => _disconnectFromDevice(device),
                                );
                              },
                            ),
                    ),
                  ],
                ),
      floatingActionButton: !kIsWeb && _isInitialized && _devices.any((d) => d.isConnected)
          ? FloatingActionButton.extended(
              onPressed: () {
                final connectedDevices = _devices.where((d) => d.isConnected).toList();
                if (connectedDevices.length == 1) {
                  _selectAndSendFile(connectedDevices.first);
                } else {
                  _showDeviceSelectionDialog(connectedDevices);
                }
              },
              icon: const Icon(Icons.send),
              label: const Text('Send File'),
            )
          : null,
    );
  }

  void _showDeviceSelectionDialog(List<DeviceInfo> connectedDevices) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Device'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: connectedDevices.map((device) => 
            ListTile(
              leading: Icon(
                Icons.device_unknown,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(device.deviceName),
              subtitle: Text(device.deviceId),
              onTap: () {
                Navigator.of(context).pop();
                _selectAndSendFile(device);
              },
            ),
          ).toList(),
        ),
      ),
    );
  }
}
