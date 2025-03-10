import 'package:flutter/material.dart';
import 'camera_page.dart';
import 'gps_page.dart';
import 'bluetooth_page.dart';
import 'microphone_page.dart';
import 'accelerometer_page.dart';

class HardwarePage extends StatefulWidget {
  const HardwarePage({super.key});

  @override
  State<HardwarePage> createState() => _HardwarePageState();
}

class _HardwarePageState extends State<HardwarePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hardware Access'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildHardwareButton(
            icon: Icons.camera_alt,
            title: 'Camera',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CameraPage(),
                ),
              );
            },
          ),
          _buildHardwareButton(
            icon: Icons.location_on,
            title: 'GPS Location',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GPSPage(),
                ),
              );
            },
          ),
          _buildHardwareButton(
            icon: Icons.bluetooth,
            title: 'Bluetooth',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BluetoothPage(),
                ),
              );
            },
          ),
          _buildHardwareButton(
            icon: Icons.mic,
            title: 'Microphone',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MicrophonePage(),
                ),
              );
            },
          ),
          _buildHardwareButton(
            icon: Icons.screen_rotation,
            title: 'Accelerometer',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AccelerometerPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHardwareButton({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: ListTile(
        leading: Icon(icon, size: 32.0),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }
} 