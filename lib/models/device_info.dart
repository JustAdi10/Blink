class DeviceInfo {
  final String deviceId;
  final String deviceName;
  final String endpointId;
  final bool isConnected;
  final bool isConnecting;

  const DeviceInfo({
    required this.deviceId,
    required this.deviceName,
    required this.endpointId,
    this.isConnected = false,
    this.isConnecting = false,
  });

  DeviceInfo copyWith({
    String? deviceId,
    String? deviceName,
    String? endpointId,
    bool? isConnected,
    bool? isConnecting,
  }) {
    return DeviceInfo(
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      endpointId: endpointId ?? this.endpointId,
      isConnected: isConnected ?? this.isConnected,
      isConnecting: isConnecting ?? this.isConnecting,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeviceInfo && other.deviceId == deviceId;
  }

  @override
  int get hashCode => deviceId.hashCode;

  @override
  String toString() {
    return 'DeviceInfo(deviceId: $deviceId, deviceName: $deviceName, endpointId: $endpointId, isConnected: $isConnected, isConnecting: $isConnecting)';
  }
}
