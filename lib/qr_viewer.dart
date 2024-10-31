// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:scan/scan.dart';

import 'bottom_navigation.dart';

class QRViewer extends StatefulWidget {
  const QRViewer({super.key});

  @override
  QRViewerHomeState createState() => QRViewerHomeState();
}

class QRViewerHomeState extends State<QRViewer> {
  Barcode? result;
  QRViewController? controller;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  bool isNavigating = false;

  void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black,
      textColor: Colors.white,
    );
  }

  void _showErrorToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: const Color(0xFFB43838),
      textColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const TabNavigator(initialIndex: 4),
          ),
        );
      },
      child: Scaffold(
        body: Stack(
          children: <Widget>[
            Positioned.fill(child: _buildQrView(context)),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    backgroundColor: const Color(0xFF08DAD6),
                    foregroundColor: Colors.black,
                  ),
                  onPressed: _scanFromGallery,
                  icon: const Icon(Icons.photo_library),
                  label: const Text("Scan Image"),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrView(BuildContext context) {
    var scanArea = (MediaQuery.of(context).size.width < 400 ||
            MediaQuery.of(context).size.height < 400)
        ? 180.0
        : 360.0;
    return QRView(
      key: qrKey,
      onQRViewCreated: _onQRViewCreated,
      overlay: QrScannerOverlayShape(
        borderColor: const Color(0xFF08DAD6),
        borderRadius: 10,
        borderLength: 30,
        borderWidth: 10,
        cutOutSize: scanArea,
      ),
      onPermissionSet: (ctrl, p) => _onPermissionSet(context, ctrl, p),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    setState(() {
      this.controller = controller;
    });
    controller.scannedDataStream.listen((scanData) {
      if (!isNavigating) {
        setState(() {
          result = scanData;
        });
        if (result != null) {
          _processScannedData(result!.code!);
        }
      }
    });
  }

  void _onPermissionSet(BuildContext context, QRViewController ctrl, bool p) {
    if (!p) {
      _showToast('No Permission');
    }
  }

  Future<void> _scanFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final String? qrCode = await Scan.parse(image.path);
        if (qrCode != null) {
          _processScannedData(qrCode);
        } else {
          _showErrorToast('No QR Code Found!');
        }
      }
    } catch (e) {
      _showErrorToast('Error scanning from gallery: $e');
    }
  }

  void _processScannedData(String data) async {
    if (!isNavigating) {
      try {
        Map<String, dynamic> qrData = json.decode(data);
        setState(() {
          isNavigating = true;
        });
        controller?.pauseCamera();

        // Fetch the latest user data from Firestore
        final userData = await fetchLatestUserData(qrData);

        Navigator.of(context)
            .push(
          MaterialPageRoute(
            builder: (context) => UserDataDisplay(userData: userData),
          ),
        )
            .then((_) {
          setState(() {
            isNavigating = false;
          });
          controller?.resumeCamera();
        });
      } catch (e) {
        _showErrorToast('Invalid QR Code');
      }
    }
  }

  Future<Map<String, dynamic>> fetchLatestUserData(
      Map<String, dynamic> qrData) async {
    try {
      // Retrieve the user document from Firestore using the email from the QR code data
      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: qrData['email'])
          .limit(1)
          .get();

      if (userSnapshot.docs.isNotEmpty) {
        // Get the latest user data from the Firestore document
        final userData = userSnapshot.docs.first.data();
        return userData;
      } else {
        // User not found in Firestore
        return {};
      }
    } catch (e) {
      // Handle any errors that occur during the Firestore query
      _showErrorToast('Error fetching user data: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}

class UserDataDisplay extends StatelessWidget {
  final Map<String, dynamic> userData;

  const UserDataDisplay({super.key, required this.userData});

  String _formatNumber(String value) {
    int? number = int.tryParse(value);
    if (number == null) return value;

    if (number >= 1000000000) {
      return '${(number / 1000000000).toStringAsFixed(1)}B';
    } else if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    } else {
      return number.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFEFEF),
      appBar: AppBar(
        elevation: 2.0,
        backgroundColor: const Color(0xFFFEFEFE),
        shadowColor: Colors.grey.withOpacity(0.5),
        centerTitle: true,
        title: Text(
          '${userData['username'].toString().toUpperCase()}\'s PROFILE',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEFEFE),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0xFFD4D4D4),
                        blurRadius: 2,
                        blurStyle: BlurStyle.outer,
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 64,
                        backgroundColor: Colors.black12,
                        child: CircleAvatar(
                          backgroundColor: Colors.transparent,
                          radius: 62,
                          backgroundImage: NetworkImage(
                            userData['photoURL'] ?? 'N/A',
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        userData['username'],
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Column(
                  children: [
                    _buildStatCard(
                      'Total Steps',
                      '${userData['totalSteps']}',
                      Icons.directions_walk,
                    ),
                    const SizedBox(height: 14),
                    _buildStatCard(
                      'Total Points',
                      '${userData['totalPoints']}',
                      Icons.star,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Column(
                  children: [
                    _buildStatCard(
                      'Trees Planted',
                      '${userData['totalTrees']}',
                      Icons.park,
                    ),
                    const SizedBox(height: 14),
                    _buildStatCard(
                      'Missions Completed',
                      '${userData['missionsCompleted']}',
                      Icons.emoji_events,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFFEFEFE),
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFFD4D4D4),
            blurRadius: 2,
            blurStyle: BlurStyle.outer,
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Icon(
              icon,
              size: 48,
              color: const Color(0xFF08DAD6),
            ),
            const SizedBox(height: 14),
            Text(
              _formatNumber(value),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
