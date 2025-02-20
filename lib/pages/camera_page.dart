import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  bool _isRecording = false;
  bool _isQRMode = false;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? qrViewController;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    qrViewController?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _controller = CameraController(
      cameras[0],
      ResolutionPreset.high,
      enableAudio: true,
    );

    try {
      await _controller!.initialize();
      setState(() => _isCameraInitialized = true);
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  Future<void> _takePicture() async {
    if (!_controller!.value.isInitialized) return;

    try {
      final image = await _controller!.takePicture();
      final directory = await getApplicationDocumentsDirectory();
      final fileName = '${DateTime.now()}.jpg';
      final savedImage = File(path.join(directory.path, fileName));
      await image.saveTo(savedImage.path);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Picture saved to ${savedImage.path}')),
      );
    } catch (e) {
      debugPrint('Error taking picture: $e');
    }
  }

  Future<void> _toggleRecording() async {
    if (!_controller!.value.isInitialized) return;

    try {
      if (_isRecording) {
        final video = await _controller!.stopVideoRecording();
        setState(() => _isRecording = false);
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Video saved to ${video.path}')),
        );
      } else {
        await _controller!.startVideoRecording();
        setState(() => _isRecording = true);
      }
    } catch (e) {
      debugPrint('Error recording video: $e');
    }
  }

  void _toggleQRMode() {
    setState(() {
      _isQRMode = !_isQRMode;
      if (!_isQRMode) {
        qrViewController?.dispose();
        _initializeCamera();
      }
    });
  }

  Widget _buildQRView() {
    return QRView(
      key: qrKey,
      onQRViewCreated: (QRViewController controller) {
        qrViewController = controller;
        controller.scannedDataStream.listen((scanData) async {
          if (!mounted) return;
          
          final code = scanData.code;
          if (code == null) return;

          // Pause scanning
          controller.pauseCamera();

          // Show a dialog to confirm opening in browser
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Open in Browser?'),
              content: Text(code),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    controller.resumeCamera(); // Resume scanning
                  },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    try {
                      // Prepare URL string
                      String urlString = code.trim();
                      if (!urlString.toLowerCase().startsWith('http')) {
                        urlString = 'https://$urlString';
                      }
                      debugPrint('Attempting to open URL: $urlString'); // Debug log

                      final uri = Uri.parse(urlString);
                      final canLaunch = await canLaunchUrl(uri);
                      debugPrint('Can launch URL: $canLaunch'); // Debug log

                      if (canLaunch) {
                        final launched = await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                          webViewConfiguration: const WebViewConfiguration(
                            enableJavaScript: true,
                            enableDomStorage: true,
                          ),
                        );
                        debugPrint('Launch result: $launched'); // Debug log
                        
                        if (!launched && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Could not open the URL')),
                          );
                        }
                      } else {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('URL is not launchable')),
                        );
                      }
                    } catch (e) {
                      debugPrint('Error launching URL: $e'); // Debug log
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: ${e.toString()}')),
                      );
                    }
                    controller.resumeCamera(); // Resume scanning
                  },
                  child: const Text('Open'),
                ),
              ],
            ),
          ).then((_) => controller.resumeCamera()); // Resume if dialog is dismissed
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera'),
        actions: [
          IconButton(
            icon: Icon(_isQRMode ? Icons.camera_alt : Icons.qr_code),
            onPressed: _toggleQRMode,
          ),
        ],
      ),
      body: _isQRMode
          ? _buildQRView()
          : Stack(
              children: [
                if (_isCameraInitialized)
                  CameraPreview(_controller!),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: Colors.black54,
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.camera_alt, color: Colors.white),
                          onPressed: _takePicture,
                        ),
                        IconButton(
                          icon: Icon(
                            _isRecording ? Icons.stop : Icons.videocam,
                            color: Colors.white,
                          ),
                          onPressed: _toggleRecording,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
} 