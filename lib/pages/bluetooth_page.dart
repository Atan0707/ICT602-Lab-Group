import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class BluetoothPage extends StatefulWidget {
  const BluetoothPage({super.key});

  @override
  State<BluetoothPage> createState() => _BluetoothPageState();
}

class _BluetoothPageState extends State<BluetoothPage> {
  FlutterBluetoothSerial bluetooth = FlutterBluetoothSerial.instance;
  List<BluetoothDevice> _devicesList = [];
  BluetoothDevice? _connectedDevice;
  BluetoothConnection? _connection;
  bool _isDiscovering = false;
  StreamSubscription<BluetoothDiscoveryResult>? _discoveryStreamSubscription;
  bool _isConnecting = false;
  bool _isDisconnecting = false;

  @override
  void initState() {
    super.initState();
    _checkBluetoothStatus();
  }

  @override
  void dispose() {
    _discoveryStreamSubscription?.cancel();
    _disconnect();
    super.dispose();
  }

  Future<void> _checkBluetoothStatus() async {
    bool? isEnabled = await bluetooth.isEnabled;
    if (isEnabled != true) {
      await bluetooth.requestEnable();
    }
    _startDiscovery();
  }

  void _startDiscovery() {
    setState(() {
      _devicesList.clear();
      _isDiscovering = true;
    });

    _discoveryStreamSubscription?.cancel();
    _discoveryStreamSubscription = bluetooth.startDiscovery().listen((result) {
      setState(() {
        final existingIndex = _devicesList.indexWhere(
            (device) => device.address == result.device.address);
        if (existingIndex >= 0) {
          _devicesList[existingIndex] = result.device;
        } else {
          _devicesList.add(result.device);
        }
      });
    });

    _discoveryStreamSubscription?.onDone(() {
      setState(() {
        _isDiscovering = false;
      });
    });
  }

  Future<void> _connect(BluetoothDevice device) async {
    if (_connection != null) {
      await _disconnect();
    }

    setState(() {
      _isConnecting = true;
    });

    try {
      _connection = await BluetoothConnection.toAddress(device.address);
      setState(() {
        _connectedDevice = device;
        _isConnecting = false;
      });

      _connection?.input?.listen(
        (Uint8List data) {
          // Handle incoming data
          print('Data incoming: ${ascii.decode(data)}');
        },
        onDone: () {
          setState(() {
            _connectedDevice = null;
          });
        },
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connected to ${device.name}')),
      );
    } catch (e) {
      setState(() {
        _isConnecting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error connecting to device: $e')),
      );
    }
  }

  Future<void> _disconnect() async {
    setState(() {
      _isDisconnecting = true;
    });

    await _connection?.close();
    
    setState(() {
      _connection = null;
      _connectedDevice = null;
      _isDisconnecting = false;
    });
  }

  Future<void> _sendFile() async {
    if (_connection == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not connected to any device')),
      );
      return;
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      
      if (result != null) {
        File file = File(result.files.single.path!);
        Uint8List fileBytes = await file.readAsBytes();
        
        // Send file name first
        _connection!.output.add(
          Uint8List.fromList(utf8.encode('FILE:${result.files.single.name}\n'))
        );
        await _connection!.output.allSent;
        
        // Send file size
        _connection!.output.add(
          Uint8List.fromList(utf8.encode('SIZE:${fileBytes.length}\n'))
        );
        await _connection!.output.allSent;
        
        // Send file content in chunks
        int chunkSize = 1024;
        for (var i = 0; i < fileBytes.length; i += chunkSize) {
          int end = (i + chunkSize < fileBytes.length) ? i + chunkSize : fileBytes.length;
          _connection!.output.add(fileBytes.sublist(i, end));
          await _connection!.output.allSent;
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File sent successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending file: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth'),
        actions: [
          if (!_isDiscovering)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _startDiscovery,
              tooltip: 'Refresh devices',
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _devicesList.length,
              itemBuilder: (context, index) {
                final device = _devicesList[index];
                final isConnected = device.address == _connectedDevice?.address;
                
                return ListTile(
                  leading: Icon(
                    Icons.bluetooth,
                    color: isConnected ? Colors.blue : Colors.grey,
                  ),
                  title: Text(device.name ?? 'Unknown Device'),
                  subtitle: Text(device.address),
                  trailing: isConnected
                      ? TextButton(
                          onPressed: _isDisconnecting ? null : _disconnect,
                          child: const Text('Disconnect'),
                        )
                      : TextButton(
                          onPressed: _isConnecting ? null : () => _connect(device),
                          child: const Text('Connect'),
                        ),
                );
              },
            ),
          ),
          if (_isDiscovering)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          if (_connectedDevice != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: _sendFile,
                icon: const Icon(Icons.send),
                label: const Text('Send File'),
              ),
            ),
        ],
      ),
    );
  }
} 