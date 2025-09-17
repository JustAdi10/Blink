import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/real_device_service.dart';

class DeviceNamingScreen extends StatefulWidget {
  final VoidCallback onDeviceNamed;
  
  const DeviceNamingScreen({
    super.key,
    required this.onDeviceNamed,
  });

  @override
  State<DeviceNamingScreen> createState() => _DeviceNamingScreenState();
}

class _DeviceNamingScreenState extends State<DeviceNamingScreen> {
  final TextEditingController _nameController = TextEditingController();
  final RealDeviceService _deviceService = RealDeviceService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentDeviceName();
  }

  Future<void> _loadCurrentDeviceName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentName = prefs.getString('device_name');
      if (currentName != null && currentName.isNotEmpty) {
        _nameController.text = currentName;
      } else {
        // Set default name based on device
        _nameController.text = 'Blink Device';
      }
    } catch (e) {
      print('Error loading device name: $e');
      _nameController.text = 'Blink Device';
    }
  }

  Future<void> _saveDeviceName() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a device name')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('device_name', _nameController.text.trim());
      
      // Update the device service with the new name
      await _deviceService.updateDeviceName(_nameController.text.trim());
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Device name saved: ${_nameController.text.trim()}')),
      );
      
      await Future.delayed(const Duration(milliseconds: 500));
      widget.onDeviceNamed();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving device name: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Name'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.phone_android,
              size: 60,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Give your device a name',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'This name will be visible to other devices when sharing files',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Device Name',
                hintText: 'Enter a name for this device',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.edit),
              ),
              maxLength: 20,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveDeviceName,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Device Name'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _isLoading ? null : () {
                  widget.onDeviceNamed();
                },
                child: const Text('Skip'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
