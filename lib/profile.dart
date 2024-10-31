// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'edit_profile.dart';
import 'offline.dart';
import 'user_trees.dart';
import 'user_certificates.dart';
import 'qr_viewer.dart';
import 'user_data_provider.dart';

class Profile extends StatelessWidget {
  const Profile({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProfileState();
  }
}

class ProfileState extends StatefulWidget {
  const ProfileState({super.key});

  @override
  UserProfileState createState() => UserProfileState();
}

class UserProfileState extends State<ProfileState> {
  final GlobalKey _qrKey = GlobalKey();
  late Stream<List<ConnectivityResult>> _connectivityStream;

  @override
  void initState() {
    super.initState();
    _connectivityStream = Connectivity().onConnectivityChanged;
    _checkConnection();
    _loadQRCodeImage();
  }

  Future<void> _checkConnection() async {
    _connectivityStream.listen((List<ConnectivityResult> results) {
      if (results.contains(ConnectivityResult.none) || results.isEmpty) {
        // No internet connection, navigate to Offline page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const Offline()),
        );
      }
    });
  }

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

  String _generateQRData(Map<String, dynamic> userData) {
    Map<String, dynamic> qrData = {
      'photoURL': userData['photoURL'],
      'username': userData['username'],
      'email': userData['email'],
      'phoneNumber': userData['phoneNumber'],
      'totalPoints': userData['totalPoints'],
      'totalSteps': userData['totalSteps'],
      'totalTrees': userData['totalTrees'],
      'missionsCompleted': userData['missionsCompleted']
    };
    return json.encode(qrData);
  }

  Future<void> _loadQRCodeImage() async {
    // Delay slightly to ensure the QR widget is rendered
    await Future.delayed(const Duration(milliseconds: 500));

    final userDataProvider =
        Provider.of<UserDataProvider>(context, listen: false);
    final userData = userDataProvider.userData!;

    // Check if the QR code image already exists in Firebase Storage
    final storageRef = FirebaseStorage.instance.ref();
    final qrImageRef = storageRef.child('qr_codes/${userData['username']}.png');

    try {
      // Check if QR code exists and user has userQrCode field
      final downloadURL = await qrImageRef.getDownloadURL();
      final hasQrCode =
          userData['userQrCode'] != null && userData['userQrCode'].isNotEmpty;

      if (!hasQrCode || downloadURL != userData['userQrCode']) {
        // If QR code doesn't exist or URLs don't match, generate and upload
        await _generateAndUploadQR(userData);
      }
    } catch (e) {
      // If the QR code image doesn't exist, generate and upload
      await _generateAndUploadQR(userData);
    }
  }

  Future<void> _generateAndUploadQR(Map<String, dynamic> userData) async {
    try {
      // Create a new GlobalKey for temporary QR generation
      final tempQrKey = GlobalKey();

      // Build the QR widget off-screen
      final qrWidget = RepaintBoundary(
        key: tempQrKey,
        child: Container(
          width: 250,
          height: 250,
          alignment: Alignment.center,
          color: const Color(0xFFFEFEFE),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                QrImageView(
                  data: _generateQRData(userData),
                  version: QrVersions.auto,
                  size: 200.0,
                  padding: const EdgeInsets.all(14),
                  backgroundColor: const Color(0xFFFEFEFE),
                ),
                Text(
                  userData['username'],
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                  ),
                )
              ],
            ),
          ),
        ),
      );

      // Insert the widget into the tree
      final overlay = OverlayEntry(
        builder: (context) => Positioned(
          left: -1000, // Position off-screen
          child: qrWidget,
        ),
      );

      Overlay.of(context).insert(overlay);

      // Wait for the widget to be rendered
      await Future.delayed(const Duration(milliseconds: 100));

      // Capture the QR code
      final RenderRepaintBoundary boundary =
          tempQrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List pngBytes = byteData!.buffer.asUint8List();

      // Remove the temporary widget
      overlay.remove();

      // Upload to Firebase Storage
      final storageRef = FirebaseStorage.instance.ref();
      final qrImageRef =
          storageRef.child('qr_codes/${userData['username']}.png');
      await qrImageRef.putData(pngBytes);

      // Get download URL
      final downloadURL = await qrImageRef.getDownloadURL();

      // Update Firestore with the download URL
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'userQrCode': downloadURL});
      }
    } catch (e) {
      _showErrorToast("Error generating QR code: $e");
    }
  }

  Future<Uint8List?> _captureAndUploadQRCode(
      BuildContext context, Map<String, dynamic> userData) async {
    try {
      RenderRepaintBoundary? boundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        ui.Image image = await boundary.toImage(pixelRatio: 3.0);
        ByteData? byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);
        Uint8List pngBytes = byteData!.buffer.asUint8List();

        // Upload to Firebase Storage
        final storageRef = FirebaseStorage.instance.ref();
        final qrImageRef =
            storageRef.child('qr_codes/${userData['username']}.png');
        await qrImageRef.putData(pngBytes);

        // Get download URL
        final downloadURL = await qrImageRef.getDownloadURL();

        // Update Firestore with the download URL
        final FirebaseAuth auth = FirebaseAuth.instance;
        User? user = auth.currentUser;

        if (user != null) {
          // Update user data in Firestore
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'userQrCode': downloadURL});
        }

        return pngBytes;
      }
    } catch (e) {
      _showErrorToast("Error capturing QR code: $e");
    }
    return null;
  }

  Future<void> _saveQRCodeToDevice(Uint8List pngBytes) async {
    // Request storage permission
    var status = await Permission.storage.request();
    if (status.isGranted) {
      final result = await ImageGallerySaver.saveImage(pngBytes);
      if (result['isSuccess']) {
        _showToast("Saved to Gallery!");
      } else {
        _showErrorToast("Failed to Saved!");
      }
    } else {
      _showToast('Permission to access storage was denied');
    }
  }

  void _showQRCodeDialog(BuildContext context, Map<String, dynamic> userData) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final userDataProvider =
            Provider.of<UserDataProvider>(context, listen: false);
        return AlertDialog(
          backgroundColor: const Color(0xFFFEFEFE),
          title: const Text(
            'MY QR CODE',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          content: RepaintBoundary(
            key: _qrKey,
            child: Container(
              width: 250,
              height: 250,
              alignment: Alignment.center,
              color: const Color(0xFFFEFEFE),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    QrImageView(
                      data: _generateQRData(userDataProvider.userData!),
                      version: QrVersions.auto,
                      size: 200.0,
                      padding: const EdgeInsets.all(14),
                      backgroundColor: const Color(0xFFFEFEFE),
                    ),
                    Text(
                      userDataProvider.userData!['username'],
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceAround,
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF08DAD6),
                surfaceTintColor: const Color(0xFF08DAD6),
              ),
              child: const Text(
                "Download",
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                ),
              ),
              onPressed: () async {
                Uint8List? pngBytes = await _captureAndUploadQRCode(
                    context, userDataProvider.userData!);
                if (pngBytes != null) {
                  await _saveQRCodeToDevice(pngBytes);
                }
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF08DAD6),
                surfaceTintColor: const Color(0xFF08DAD6),
              ),
              child: const Text(
                "Close",
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _navigateToEditProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const EditProfile(),
      ),
    );

    if (!mounted) return;
    // Refresh data after returning
    Provider.of<UserDataProvider>(context, listen: false).refreshUserData();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserDataProvider>(
      builder: (context, userDataProvider, child) {
        if (userDataProvider.userData == null &&
            userDataProvider.missionData == null) {
          return const Scaffold(
            backgroundColor: Color(0xFFEFEFEF),
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF08DAD6),
                strokeWidth: 6.0,
              ),
            ),
          );
        }
        return PopScope(
          canPop: false,
          onPopInvoked: (didPop) {
            try {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text(
                      textAlign: TextAlign.center,
                      'Close TreeStride?',
                      style: TextStyle(
                        fontSize: 24,
                        color: Colors.black,
                      ),
                    ),
                    actionsAlignment: MainAxisAlignment.spaceAround,
                    actions: <Widget>[
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF08DAD6),
                          surfaceTintColor: const Color(0xFF08DAD6),
                        ),
                        child: const Text(
                          'Stay',
                          style: TextStyle(
                            color: Colors.black,
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF08DAD6),
                          surfaceTintColor: const Color(0xFF08DAD6),
                        ),
                        child: const Text(
                          'Close',
                          style: TextStyle(
                            color: Colors.black,
                          ),
                        ),
                        onPressed: () {
                          SystemNavigator.pop();
                        },
                      ),
                    ],
                  );
                },
              );
            } catch (error) {
              _showErrorToast("Closing Error: $error");
            }
          },
          child: Scaffold(
            backgroundColor: const Color(0xFFEFEFEF),
            appBar: AppBar(
              elevation: 2,
              automaticallyImplyLeading: false,
              backgroundColor: const Color(0xFFFEFEFE),
              shadowColor: Colors.grey.withOpacity(0.5),
              leading: IconButton(
                icon: const Icon(Icons.qr_code),
                onPressed: () {
                  _showQRCodeDialog(context, userDataProvider.userData!);
                },
              ),
              centerTitle: true,
              title: const Text(
                'PROFILE',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
              actions: [
                IconButton(
                  onPressed: _navigateToEditProfile,
                  icon: const Icon(Icons.edit),
                ),
              ],
            ),
            body: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildProfileHeader(context, userDataProvider),
                      const SizedBox(height: 14),
                      _buildStatsSection(userDataProvider),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEFEFE),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: const [
                            BoxShadow(
                              color: ui.Color(0xFFD4D4D4),
                              blurRadius: 2,
                              blurStyle: BlurStyle.outer,
                            )
                          ],
                        ),
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.directions_walk,
                              size: 24,
                              color: Color(0xFF08DAD6),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                "Total Steps",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatNumber(
                                userDataProvider.userData!['totalSteps'],
                              ),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEFEFE),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: const [
                            BoxShadow(
                              color: ui.Color(0xFFD4D4D4),
                              blurRadius: 2,
                              blurStyle: BlurStyle.outer,
                            )
                          ],
                        ),
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.star,
                              size: 24,
                              color: Color(0xFF08DAD6),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                "Total Points",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatNumber(
                                userDataProvider.userData!['totalPoints'],
                              ),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEFEFE),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: const [
                            BoxShadow(
                              color: ui.Color(0xFFD4D4D4),
                              blurRadius: 2,
                              blurStyle: BlurStyle.outer,
                            )
                          ],
                        ),
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.emoji_events,
                              size: 24,
                              color: Color(0xFF08DAD6),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                "Missions Completed",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatNumber(
                                userDataProvider.userData!['missionsCompleted'],
                              ),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader(
      BuildContext context, UserDataProvider userDataProvider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: const Color(0xFFFEFEFE),
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(
            color: ui.Color(0xFFD4D4D4),
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
              radius: 62,
              backgroundImage: NetworkImage(
                userDataProvider.userData!['photoURL'] ?? 'N/A',
              ),
              onBackgroundImageError: (error, stacktrace) => const Icon(
                Icons.image,
                size: 64,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            userDataProvider.userData!['username'],
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            userDataProvider.userData!['email'],
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
          Text(
            userDataProvider.userData!['phoneNumber'],
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const QRViewer(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              backgroundColor: const Color(0xFF08DAD6),
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 8,
              ),
            ),
            icon: const Icon(
              Icons.qr_code_scanner,
              color: Colors.black,
            ),
            label: const Text(
              'SCAN QR CODE',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(UserDataProvider userDataProvider) {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PlantedTrees(),
              ),
            );
          },
          child: _buildStatCard(
            'Trees Planted',
            userDataProvider.userData!['totalTrees'],
            Icons.park,
            Icons.arrow_forward,
          ),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const UserCertificates(),
              ),
            );
          },
          child: _buildStatCard(
            'Certificates',
            userDataProvider.userData!['certificates'],
            Icons.workspace_premium,
            Icons.arrow_forward,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, IconData arrow) {
    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFFEFEFE),
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(
            color: ui.Color(0xFFD4D4D4),
            blurRadius: 2,
            blurStyle: BlurStyle.outer,
          )
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Icon(icon, size: 24, color: const Color(0xFF08DAD6)),
          const SizedBox(width: 8),
          Text(
            title,
            textAlign: TextAlign.left,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              textAlign: TextAlign.left,
              _formatNumber(value),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Icon(arrow, size: 24, color: const Color(0xFF08DAD6)),
        ],
      ),
    );
  }
}

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
