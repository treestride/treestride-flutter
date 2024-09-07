// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:treestride/offline.dart';
import 'package:treestride/plant_tree.dart';

class Certificate extends StatefulWidget {
  final Map<String, dynamic> treeData;
  final int userTotalTrees;
  final int userCertificates;
  final String userProfile;
  final String username;

  const Certificate({
    super.key,
    required this.treeData,
    required this.userTotalTrees,
    required this.userCertificates,
    required this.userProfile,
    required this.username,
  });

  @override
  CertificateState createState() => CertificateState();
}

class CertificateState extends State<Certificate> {
  final ScreenshotController screenshotController = ScreenshotController();
  late Stream<List<ConnectivityResult>> _connectivityStream;
  final GlobalKey _globalKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _connectivityStream = Connectivity().onConnectivityChanged;
    _checkConnection();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _captureAndSaveCertificate();
    });
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

  Future<void> _captureAndSavePng(BuildContext context) async {
    try {
      // Request storage permission
      var status = await Permission.storage.request();
      if (status.isGranted) {
        // Capture the image
        final RenderRepaintBoundary boundary = _globalKey.currentContext!
            .findRenderObject() as RenderRepaintBoundary;
        final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
        final ByteData? byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);

        if (byteData == null) {
          _showErrorToast('Failed to capture certificate');
          return;
        }

        final Uint8List pngBytes = byteData.buffer.asUint8List();

        // Save the image to gallery
        final result = await ImageGallerySaver.saveImage(pngBytes,
            quality: 100,
            name: "certificate_${DateTime.now().millisecondsSinceEpoch}.png");

        if (result['isSuccess']) {
          _showToast('Saved to Gallery!');
        } else {
          _showErrorToast('Failed to save certificate');
        }
      } else {
        _showToast('Permission to access storage was denied');
      }
    } catch (e) {
      _showErrorToast('Error saving certificate: $e');
    }
  }

  Future<void> _captureAndSharePng(BuildContext context) async {
    try {
      // Capture the image
      final RenderRepaintBoundary boundary = _globalKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        _showErrorToast('Failed to capture the certificate');
        return;
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // Get temporary directory
      final directory = await getTemporaryDirectory();
      final imagePath =
          await File('${directory.path}/certificate.png').create();
      await imagePath.writeAsBytes(pngBytes);

      // Share the image
      await Share.shareXFiles([XFile(imagePath.path)],
          text: 'My Tree Planting Certificate');
    } catch (e) {
      _showErrorToast('Error sharing certificate: $e');
    }
  }

  Future<void> _captureAndSaveCertificate() async {
    // Wait for the widget to be fully rendered
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    try {
      await _saveCertificateToFirebase();
    } catch (e) {
      _showErrorToast('Error saving certificate: $e');
    }
  }

  Future<void> _saveCertificateToFirebase() async {
    if (!mounted) return;
    try {
      if (_globalKey.currentContext == null) {
        _showErrorToast('Widget not rendered yet');
        return;
      }

      // Capture the certificate as an image
      final RenderRepaintBoundary? boundary = _globalKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        _showErrorToast('Failed to find render object');
        return;
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        _showErrorToast('Failed to capture the certificate');
        return;
      }

      final Uint8List imageData = byteData.buffer.asUint8List();

      // Get the current user
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showErrorToast('User not logged in');
        return;
      }

      // Generate a unique filename for the certificate
      final String fileName =
          'certificates/${user.uid}_${DateTime.now().millisecondsSinceEpoch}.png';

      // Upload the image to Firebase Storage
      final Reference storageRef =
          FirebaseStorage.instance.ref().child(fileName);
      final UploadTask uploadTask = storageRef.putData(imageData);
      final TaskSnapshot snapshot = await uploadTask;

      // Get the download URL of the uploaded image
      final String downloadURL = await snapshot.ref.getDownloadURL();

      // Create a certificate document
      final certificateData = {
        'imageUrl': downloadURL,
        'treeName': widget.treeData['name'],
        'treeType': widget.treeData['type'],
        'date': FieldValue.serverTimestamp(),
        'certificateNumber': widget.userCertificates,
      };

      // Add the certificate to the user's certificates collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('user_certificates')
          .add(certificateData);
    } catch (e) {
      _showErrorToast('Error saving certificate: $e');
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        textTheme: GoogleFonts.exo2TextTheme(
          Theme.of(context).textTheme,
        ),
        primaryTextTheme: GoogleFonts.exoTextTheme(
          Theme.of(context).primaryTextTheme,
        ),
      ),
      home: PopScope(
        canPop: false,
        onPopInvoked: (didPop) async {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const TreeShop(),
            ),
          );
        },
        child: Scaffold(
          backgroundColor: const Color(0xFFEFEFEF),
          appBar: AppBar(
            elevation: 2.0,
            backgroundColor: const Color(0xFFFEFEFE),
            shadowColor: Colors.grey.withOpacity(0.5),
            leading: IconButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TreeShop(),
                  ),
                );
              },
              icon: const Icon(
                Icons.arrow_back,
              ),
              iconSize: 24,
            ),
            centerTitle: true,
            title: const Text(
              'CERTIFICATE',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          body: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    RepaintBoundary(
                      key: _globalKey,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                            color: Colors.green[700]!,
                            width: 2,
                          ),
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
                              Text(
                                'Certificate of Tree Planting',
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[700],
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'This is to certify that',
                                style: GoogleFonts.lato(fontSize: 18),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                widget.username,
                                style: GoogleFonts.dancingScript(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'has successfully planted',
                                style: GoogleFonts.lato(fontSize: 18),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '${widget.treeData['name']}',
                                style: GoogleFonts.merriweather(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[800],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '(${widget.treeData['type']})',
                                style: GoogleFonts.lato(
                                  fontSize: 18,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Contributing to a total of',
                                style: GoogleFonts.lato(fontSize: 18),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '${widget.userTotalTrees} Trees Planted',
                                style: GoogleFonts.merriweather(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[800],
                                ),
                              ),
                              const SizedBox(height: 30),
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: const Color(0xFF2E7D32),
                                    width: 2,
                                  ),
                                  shape: BoxShape.circle,
                                  image: DecorationImage(
                                    fit: BoxFit.cover,
                                    image: NetworkImage(widget.userProfile),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Certificate #${widget.userCertificates}',
                                style: GoogleFonts.lato(
                                  fontSize: 16,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _captureAndSharePng(context),
                            icon: const Icon(Icons.share),
                            label: const Text("Share"),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: const Color(0xFF08DAD6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _captureAndSavePng(context),
                            icon: const Icon(Icons.download),
                            label: const Text("Download"),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: const Color(0xFF08DAD6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF08DAD6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: Text(
                        'BACK TO SHOP',
                        style: GoogleFonts.lato(
                          fontSize: 16,
                          color: Colors.black,
                        ),
                      ),
                      onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TreeShop(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
