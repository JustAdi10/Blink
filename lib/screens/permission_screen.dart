import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

class PermissionScreen extends StatefulWidget {
  final VoidCallback onPermissionsGranted;
  
  const PermissionScreen({
    super.key,
    required this.onPermissionsGranted,
  });

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  bool _isLoading = false;
  String _statusMessage = 'Checking permissions...';
  int? _androidApiLevel;
  
  @override
  void initState() {
    super.initState();
    _detectAndroidVersion();
  }

  Future<void> _detectAndroidVersion() async {
    if (kIsWeb) {
      // Skip Android detection on web
      _checkPermissions();
      return;
    }
    
    if (Platform.isAndroid) {
      try {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        _androidApiLevel = androidInfo.version.sdkInt;
        print('Android API Level: $_androidApiLevel');
      } catch (e) {
        print('Error detecting Android version: $e');
      }
    }
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    setState(() {
      _statusMessage = 'Checking permissions...';
    });

    // Check current status first without requesting
    final Map<Permission, PermissionStatus> statuses = {};
    
    // Check core permissions
    statuses[Permission.location] = await Permission.location.status;
    statuses[Permission.bluetooth] = await Permission.bluetooth.status;
    
    // Check version-specific permissions
    if (!kIsWeb && Platform.isAndroid) {
      if (_androidApiLevel != null && _androidApiLevel! >= 31) {
        statuses[Permission.bluetoothAdvertise] = await Permission.bluetoothAdvertise.status;
        statuses[Permission.bluetoothConnect] = await Permission.bluetoothConnect.status;
        statuses[Permission.bluetoothScan] = await Permission.bluetoothScan.status;
      }
      
      if (_androidApiLevel != null && _androidApiLevel! >= 33) {
        statuses[Permission.nearbyWifiDevices] = await Permission.nearbyWifiDevices.status;
        statuses[Permission.photos] = await Permission.photos.status;
        statuses[Permission.videos] = await Permission.videos.status;
        statuses[Permission.audio] = await Permission.audio.status;
      } else {
        statuses[Permission.storage] = await Permission.storage.status;
      }
    } else if (!kIsWeb) {
      // iOS permissions
      statuses[Permission.photos] = await Permission.photos.status;
      statuses[Permission.videos] = await Permission.videos.status;
      statuses[Permission.audio] = await Permission.audio.status;
    }

    // Check if we need to request permissions
    final needsRequest = statuses.values.any((status) => 
        status.isDenied || status.isPermanentlyDenied);
    
    bool allGranted = true;
    List<String> deniedPermissions = [];

    for (final entry in statuses.entries) {
      if (entry.value != PermissionStatus.granted) {
        allGranted = false;
        deniedPermissions.add(_getPermissionName(entry.key));
      }
    }

    // For Android, we can proceed if core permissions are granted
    // Storage permissions work differently across Android versions
    if (!kIsWeb && Platform.isAndroid) {
      // Check core permissions for all Android versions
      bool corePermissionsGranted = statuses[Permission.location]?.isGranted == true &&
          statuses[Permission.bluetooth]?.isGranted == true;
      
      // Check version-specific permissions
      if (_androidApiLevel != null && _androidApiLevel! >= 31) {
        // Android 12+ requires new Bluetooth permissions
        corePermissionsGranted = corePermissionsGranted &&
            statuses[Permission.bluetoothAdvertise]?.isGranted == true &&
            statuses[Permission.bluetoothConnect]?.isGranted == true &&
            statuses[Permission.bluetoothScan]?.isGranted == true;
      }
      
      if (_androidApiLevel != null && _androidApiLevel! >= 33) {
        // Android 13+ requires nearby WiFi devices permission
        corePermissionsGranted = corePermissionsGranted &&
            statuses[Permission.nearbyWifiDevices]?.isGranted == true;
      }
      
      if (corePermissionsGranted) {
        String versionInfo = '';
        if (_androidApiLevel != null) {
          if (_androidApiLevel! >= 33) {
            versionInfo = ' (Android 13+)';
          } else if (_androidApiLevel! >= 31) {
            versionInfo = ' (Android 12)';
          } else if (_androidApiLevel! >= 30) {
            versionInfo = ' (Android 11)';
          }
        }
        
        setState(() {
          _statusMessage = 'Core permissions granted! Proceeding...$versionInfo';
        });
        await Future.delayed(const Duration(seconds: 1));
        widget.onPermissionsGranted();
        return;
      }
    }
    
    // For web, just proceed
    if (kIsWeb) {
      setState(() {
        _statusMessage = 'Web platform - proceeding...';
      });
      await Future.delayed(const Duration(seconds: 1));
      widget.onPermissionsGranted();
      return;
    }

    if (allGranted) {
      setState(() {
        _statusMessage = 'All permissions granted!';
      });
      await Future.delayed(const Duration(seconds: 1));
      widget.onPermissionsGranted();
    } else {
      setState(() {
        _statusMessage = 'Some permissions were denied:\n${deniedPermissions.join(', ')}';
      });
    }
  }


  String _getPermissionName(Permission permission) {
    switch (permission) {
      case Permission.location:
        return 'Location';
      case Permission.bluetooth:
        return 'Bluetooth';
      case Permission.bluetoothAdvertise:
        return 'Bluetooth Advertise';
      case Permission.bluetoothConnect:
        return 'Bluetooth Connect';
      case Permission.bluetoothScan:
        return 'Bluetooth Scan';
      case Permission.photos:
        return 'Photos';
      case Permission.videos:
        return 'Videos';
      case Permission.audio:
        return 'Audio';
      case Permission.storage:
        return 'Storage';
      case Permission.nearbyWifiDevices:
        return 'Nearby WiFi Devices';
      default:
        return permission.toString();
    }
  }

  Future<void> _requestPermissionsManually() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Requesting permissions...';
    });

    try {
      // Request core permissions individually
      setState(() {
        _statusMessage = 'Requesting location permission...';
      });
      final locationStatus = await Permission.location.request();
      if (locationStatus == PermissionStatus.permanentlyDenied) {
        setState(() {
          _statusMessage = 'Location permission is permanently denied. Please enable it in Settings.';
        });
        await Future.delayed(const Duration(seconds: 2));
        await _openAppSettings();
        return;
      }
      
      setState(() {
        _statusMessage = 'Requesting Bluetooth permission...';
      });
      final bluetoothStatus = await Permission.bluetooth.request();
      if (bluetoothStatus == PermissionStatus.permanentlyDenied) {
        setState(() {
          _statusMessage = 'Bluetooth permission is permanently denied. Please enable it in Settings.';
        });
        await Future.delayed(const Duration(seconds: 2));
        await _openAppSettings();
        return;
      }
      
      // Request version-specific permissions
      if (!kIsWeb && Platform.isAndroid) {
        if (_androidApiLevel != null && _androidApiLevel! >= 31) {
          // Android 12+ Bluetooth permissions
          setState(() {
            _statusMessage = 'Requesting Bluetooth permissions (Android 12+)...';
          });
          
          final advertiseStatus = await Permission.bluetoothAdvertise.request();
          final connectStatus = await Permission.bluetoothConnect.request();
          final scanStatus = await Permission.bluetoothScan.request();
          
          if (advertiseStatus == PermissionStatus.permanentlyDenied ||
              connectStatus == PermissionStatus.permanentlyDenied ||
              scanStatus == PermissionStatus.permanentlyDenied) {
            setState(() {
              _statusMessage = 'Some Bluetooth permissions are permanently denied. Please enable them in Settings.';
            });
            await Future.delayed(const Duration(seconds: 2));
            await _openAppSettings();
            return;
          }
        }
      }
      
      // Request media permissions based on platform
      if (!kIsWeb && Platform.isAndroid) {
        if (_androidApiLevel != null && _androidApiLevel! >= 33) {
          // Android 13+ permissions
          setState(() {
            _statusMessage = 'Requesting media permissions (Android 13+)...';
          });
          
          final nearbyWifiStatus = await Permission.nearbyWifiDevices.request();
          final photosStatus = await Permission.photos.request();
          final videosStatus = await Permission.videos.request();
          final audioStatus = await Permission.audio.request();
          
          if (photosStatus == PermissionStatus.permanentlyDenied ||
              videosStatus == PermissionStatus.permanentlyDenied ||
              audioStatus == PermissionStatus.permanentlyDenied) {
            setState(() {
              _statusMessage = 'Some media permissions are permanently denied. Please enable them in Settings.';
            });
            await Future.delayed(const Duration(seconds: 2));
            await _openAppSettings();
            return;
          }
        } else {
          // Android 11-12 storage permission
          setState(() {
            _statusMessage = 'Requesting storage permission (Android 11-12)...';
          });
          
          final storageStatus = await Permission.storage.request();
          if (storageStatus == PermissionStatus.permanentlyDenied) {
            setState(() {
              _statusMessage = 'Storage permission is permanently denied. Please enable it in Settings.';
            });
            await Future.delayed(const Duration(seconds: 2));
            await _openAppSettings();
            return;
          }
        }
      } else if (!kIsWeb) {
        // iOS permissions
        setState(() {
          _statusMessage = 'Requesting media permissions (iOS)...';
        });
        
        final photosStatus = await Permission.photos.request();
        final videosStatus = await Permission.videos.request();
        final audioStatus = await Permission.audio.request();
        
        if (photosStatus == PermissionStatus.permanentlyDenied ||
            videosStatus == PermissionStatus.permanentlyDenied ||
            audioStatus == PermissionStatus.permanentlyDenied) {
          setState(() {
            _statusMessage = 'Some media permissions are permanently denied. Please enable them in Settings.';
          });
          await Future.delayed(const Duration(seconds: 2));
          await _openAppSettings();
          return;
        }
      }
      
      // Check if all permissions are now granted
      await _checkPermissions();
    } catch (e) {
      setState(() {
        _statusMessage = 'Error requesting permissions: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _openAppSettings() async {
    await openAppSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Permissions Required'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.security,
              size: 60,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Blink needs permissions to work properly',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'To enable peer-to-peer file sharing, Blink needs access to:',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _PermissionList(androidApiLevel: _androidApiLevel),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  if (_isLoading)
                    const CircularProgressIndicator()
                  else
                    Icon(
                      _statusMessage.contains('granted') 
                          ? Icons.check_circle 
                          : Icons.warning,
                      color: _statusMessage.contains('granted')
                          ? Colors.green
                          : Colors.orange,
                      size: 32,
                    ),
                  const SizedBox(height: 12),
                  Text(
                    _statusMessage,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _requestPermissionsManually,
                    child: const Text('Request Permissions'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _openAppSettings,
                    child: const Text('Open Settings'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _isLoading ? null : () {
                  widget.onPermissionsGranted();
                },
                child: const Text('Skip & Continue'),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'If permissions are denied, you can enable them manually in Settings > Apps > Blink > Permissions',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionList extends StatelessWidget {
  final int? androidApiLevel;
  
  const _PermissionList({this.androidApiLevel});

  @override
  Widget build(BuildContext context) {
    final permissions = [
      {'icon': Icons.location_on, 'name': 'Location', 'description': 'Required for device discovery'},
      {'icon': Icons.bluetooth, 'name': 'Bluetooth', 'description': 'Required for peer-to-peer connections'},
      {'icon': Icons.wifi, 'name': 'WiFi', 'description': 'Required for network discovery'},
    ];
    
    // Add storage permissions based on Android version
    if (kIsWeb) {
      // Web doesn't need these permissions
      return Column(
        children: [
          Text(
            'Web platform detected - permissions not applicable',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      );
    }
    
    if (Platform.isAndroid) {
      if (androidApiLevel != null && androidApiLevel! >= 33) {
        // Android 13+ uses granular media permissions
        permissions.addAll([
          {'icon': Icons.photo, 'name': 'Photos', 'description': 'Required to access photos (Android 13+)'},
          {'icon': Icons.video_library, 'name': 'Videos', 'description': 'Required to access videos (Android 13+)'},
          {'icon': Icons.audiotrack, 'name': 'Audio', 'description': 'Required to access audio files (Android 13+)'},
        ]);
      } else {
        // Android 11-12 uses legacy storage permissions
        permissions.add({'icon': Icons.storage, 'name': 'Storage', 'description': 'Required for file transfers (Android 11-12)'});
      }
    } else {
      // iOS
      permissions.addAll([
        {'icon': Icons.photo, 'name': 'Photos', 'description': 'Required to access photos'},
        {'icon': Icons.video_library, 'name': 'Videos', 'description': 'Required to access videos'},
        {'icon': Icons.audiotrack, 'name': 'Audio', 'description': 'Required to access audio files'},
      ]);
    }

    return Column(
      children: permissions.map((permission) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Icon(
              permission['icon'] as IconData,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    permission['name'] as String,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    permission['description'] as String,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }
}
