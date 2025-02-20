import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';

class AccelerometerPage extends StatefulWidget {
  const AccelerometerPage({super.key});

  @override
  State<AccelerometerPage> createState() => _AccelerometerPageState();
}

class _AccelerometerPageState extends State<AccelerometerPage> {
  final _streamSubscriptions = <StreamSubscription<dynamic>>[];
  AccelerometerEvent? _accelerometerEvent;

  @override
  void initState() {
    super.initState();
    _streamSubscriptions.add(
      accelerometerEvents.listen(
        (AccelerometerEvent event) {
          setState(() {
            _accelerometerEvent = event;
          });
        },
      ),
    );
  }

  @override
  void dispose() {
    for (final subscription in _streamSubscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accelerometer Data'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.screen_rotation,
              size: 80.0,
              color: Colors.blue,
            ),
            const SizedBox(height: 20),
            const Text(
              'Accelerometer Values',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Card(
              margin: const EdgeInsets.all(16.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildAccelerometerValue('X-Axis', _accelerometerEvent?.x),
                    const Divider(),
                    _buildAccelerometerValue('Y-Axis', _accelerometerEvent?.y),
                    const Divider(),
                    _buildAccelerometerValue('Z-Axis', _accelerometerEvent?.z),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Move your device to see changes',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccelerometerValue(String axis, double? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            axis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          Text(
            value?.toStringAsFixed(2) ?? 'N/A',
            style: const TextStyle(fontSize: 18),
          ),
        ],
      ),
    );
  }
} 