import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QRScannerScreen extends StatefulWidget {
  @override
  _QRScannerScreenState createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  String scannedData = "";
  bool isLoading = false;
  String errorMessage = "";
  bool isBeepSoundEnabled = true;
  final AudioPlayer audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      isBeepSoundEnabled = prefs.getBool('isBeepSoundEnabled') ?? true;
    });
  }

  void _onDetect(BarcodeCapture barcodeCapture) async {
    final barcode = barcodeCapture.barcodes.first;
    if (scannedData.isEmpty) {
      setState(() {
        scannedData = barcode.rawValue!;
        isLoading = true;
        errorMessage = "";
      });
      try {
        if (isBeepSoundEnabled) {
          await audioPlayer.play(AssetSource('beep.mp3')); // Play beep sound
        }
        // Reset scannedData after a short delay to allow scanning another QR code
        Future.delayed(Duration(seconds: 2), () {
          setState(() {
            scannedData = "";
          });
        });
      } catch (e) {
        setState(() {
          errorMessage = "Error processing scan: $e";
        });
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("QR Scanner")),
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                MobileScanner(
                  onDetect: _onDetect,
                ),
                Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.red, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: isLoading
                  ? CircularProgressIndicator()
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(height: 20), // Add space above the text
                        Text(scannedData.isNotEmpty ? "Scanned: $scannedData" : "Scan a QR code"),
                        if (errorMessage.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              errorMessage,
                              style: TextStyle(color: Colors.red),
                            ),
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
