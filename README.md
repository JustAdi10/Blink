# Blink - AirDrop-like File Sharing

A cross-platform Flutter application that mimics AirDrop-like file sharing using Wi-Fi Direct and Multipeer connectivity.

## Features

- **Peer Discovery**: Automatically discovers nearby devices running Blink
- **Device Connection**: Connect/disconnect to/from nearby devices
- **File Transfer**: Send and receive files with progress tracking
- **Modern UI**: Material 3 design with clean, intuitive interface
- **Cross-Platform**: Works on both iOS and Android

## Architecture

The app is built with a modular architecture:

- `services/device_service.dart` - Handles peer discovery and connection management
- `services/transfer_service.dart` - Manages file sending/receiving logic
- `widgets/progress_bar.dart` - Reusable progress indicator components
- `widgets/device_tile.dart` - Device list item components
- `screens/home_screen.dart` - Main screen with device list
- `screens/transfer_progress_screen.dart` - Transfer progress tracking

## Dependencies

- `flutter_nearby_connections` - Peer-to-peer connections
- `file_picker` - File selection
- `path_provider` - File system access
- `open_filex` - File opening

## Setup

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd blink
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

## Platform Requirements

### Supported Platforms
- **Android**: Minimum SDK 21 (Android 5.0), Target SDK 34
- **iOS**: Minimum iOS 12.0
- **Web**: Not supported (shows informational message)

### Required Permissions

**Android:**
- WiFi, Bluetooth, Location, Storage permissions
- Nearby WiFi devices access

**iOS:**
- Bluetooth, Location, Local Network permissions
- Bonjour service: `_blink_share._tcp`

## Usage

1. **Launch the app** on multiple devices
2. **Wait for discovery** - devices will automatically appear in the list
3. **Connect to a device** by tapping the connect button
4. **Send files** using the floating action button when connected
5. **Monitor progress** in the transfer progress screen

## Development

The codebase is structured for easy extension:

- **Chunking**: Add file chunking for large files
- **BLE Discovery**: Implement Bluetooth Low Energy discovery
- **Cloud Fallback**: Add cloud-based file sharing as backup
- **Multiple Files**: Support batch file transfers

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test on both platforms
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
