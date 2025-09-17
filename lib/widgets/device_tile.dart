import 'package:flutter/material.dart';
import '../models/device_info.dart';

class DeviceTile extends StatelessWidget {
  final DeviceInfo device;
  final VoidCallback? onTap;
  final bool showConnectionStatus;

  const DeviceTile({
    super.key,
    required this.device,
    this.onTap,
    this.showConnectionStatus = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: InkWell(
        onTap: device.isConnected || device.isConnecting ? null : onTap,
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 48.0,
                height: 48.0,
                decoration: BoxDecoration(
                  color: _getDeviceColor(colorScheme),
                  borderRadius: BorderRadius.circular(24.0),
                ),
                child: Icon(
                  Icons.device_unknown,
                  color: colorScheme.onPrimary,
                  size: 24.0,
                ),
              ),
              const SizedBox(width: 16.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.deviceName,
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      device.deviceId,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (showConnectionStatus) ...[
                const SizedBox(width: 8.0),
                _buildConnectionStatus(colorScheme),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionStatus(ColorScheme colorScheme) {
    if (device.isConnecting) {
      return SizedBox(
        width: 20.0,
        height: 20.0,
        child: CircularProgressIndicator(
          strokeWidth: 2.0,
          valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
        ),
      );
    } else if (device.isConnected) {
      return Container(
        width: 20.0,
        height: 20.0,
        decoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: Icon(
          Icons.check,
          color: colorScheme.onPrimary,
          size: 14.0,
        ),
      );
    } else {
      return Container(
        width: 20.0,
        height: 20.0,
        decoration: BoxDecoration(
          color: colorScheme.outline,
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: Icon(
          Icons.circle,
          color: colorScheme.surface,
          size: 14.0,
        ),
      );
    }
  }

  Color _getDeviceColor(ColorScheme colorScheme) {
    if (device.isConnected) {
      return colorScheme.primary;
    } else if (device.isConnecting) {
      return colorScheme.secondary;
    } else {
      return colorScheme.surfaceVariant;
    }
  }
}

class DeviceListTile extends StatelessWidget {
  final DeviceInfo device;
  final VoidCallback? onConnect;
  final VoidCallback? onDisconnect;
  final bool showActions;

  const DeviceListTile({
    super.key,
    required this.device,
    this.onConnect,
    this.onDisconnect,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              width: 48.0,
              height: 48.0,
              decoration: BoxDecoration(
                color: _getDeviceColor(colorScheme),
                borderRadius: BorderRadius.circular(24.0),
              ),
              child: Icon(
                Icons.device_unknown,
                color: colorScheme.onPrimary,
                size: 24.0,
              ),
            ),
            const SizedBox(width: 16.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.deviceName,
                    style: theme.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    device.deviceId,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (showActions) ...[
              const SizedBox(width: 8.0),
              _buildActionButton(colorScheme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(ColorScheme colorScheme) {
    if (device.isConnecting) {
      return SizedBox(
        width: 32.0,
        height: 32.0,
        child: CircularProgressIndicator(
          strokeWidth: 2.0,
          valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
        ),
      );
    } else if (device.isConnected) {
      return IconButton(
        onPressed: onDisconnect,
        icon: Icon(
          Icons.close,
          color: colorScheme.error,
        ),
        tooltip: 'Disconnect',
      );
    } else {
      return IconButton(
        onPressed: onConnect,
        icon: Icon(
          Icons.link,
          color: colorScheme.primary,
        ),
        tooltip: 'Connect',
      );
    }
  }

  Color _getDeviceColor(ColorScheme colorScheme) {
    if (device.isConnected) {
      return colorScheme.primary;
    } else if (device.isConnecting) {
      return colorScheme.secondary;
    } else {
      return colorScheme.surfaceVariant;
    }
  }
}
