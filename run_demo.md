# Running Blink - Platform Demo

## Mobile Platforms (Recommended)

### Android
```bash
# Connect Android device or start emulator
flutter devices

# Run on Android
flutter run -d android
```

### iOS
```bash
# Connect iOS device or start simulator
flutter devices

# Run on iOS
flutter run -d ios
```

## Web Platform (Limited Support)

The app will run on web but shows an informational message since peer-to-peer file sharing requires mobile platforms.

```bash
# Run on web
flutter run -d web
```

## Testing File Sharing

1. **Install on multiple devices**: Run the app on at least 2 mobile devices
2. **Enable permissions**: Grant WiFi, Bluetooth, and Location permissions
3. **Wait for discovery**: Devices should appear in each other's lists
4. **Connect devices**: Tap the connect button on one device
5. **Send files**: Use the floating action button to select and send files
6. **Monitor progress**: Check the transfer progress screen

## Troubleshooting

- **No devices found**: Ensure both devices have WiFi and Bluetooth enabled
- **Permission denied**: Check device settings for required permissions
- **Connection failed**: Try restarting the app on both devices
- **Web errors**: Expected - use mobile devices for full functionality

## Development Notes

- The app gracefully handles web platform limitations
- All core functionality works on mobile platforms
- Platform checks prevent crashes on unsupported platforms
