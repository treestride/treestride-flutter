import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:image_gallery_saver/image_gallery_saver.dart';

import 'bottom_navigation.dart';
import 'offline.dart';

class UserCertificates extends StatefulWidget {
  const UserCertificates({super.key});

  @override
  UserCertificatesState createState() => UserCertificatesState();
}

class UserCertificatesState extends State<UserCertificates> {
  late Stream<List<ConnectivityResult>> _connectivityStream;
  final int _batchSize = 3;
  final List<DocumentSnapshot> _certificates = [];
  bool _hasMore = true;
  bool _isLoading = false;
  DocumentSnapshot? _lastDocument;

  @override
  void initState() {
    super.initState();
    _connectivityStream = Connectivity().onConnectivityChanged;
    _checkConnection();
    _fetchCertificates();
  }

  Future<void> _checkConnection() async {
    _connectivityStream.listen((List<ConnectivityResult> results) {
      if (results.contains(ConnectivityResult.none) || results.isEmpty) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const Offline()),
        );
      }
    });
  }

  Future<void> _fetchCertificates() async {
    if (!_hasMore || _isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        Fluttertoast.showToast(
          msg: "User is not logged in",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return;
      }

      Query query = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('user_certificates')
          .orderBy('date', descending: true)
          .limit(_batchSize);

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final querySnapshot = await query.get();

      setState(() {
        _certificates.addAll(querySnapshot.docs);
        _lastDocument =
            querySnapshot.docs.isNotEmpty ? querySnapshot.docs.last : null;
        _hasMore = querySnapshot.docs.length >= _batchSize;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _shareCertificate(
      String imageUrl, String treeName, String treeType) async {
    final response = await http.get(Uri.parse(imageUrl));
    final bytes = response.bodyBytes;
    final temp = await getTemporaryDirectory();
    final path = '${temp.path}/certificate.jpg';
    File(path).writeAsBytesSync(bytes);

    await Share.shareXFiles(
      [XFile(path)],
      text: 'Check out my $treeName ($treeType) certificate!',
    );
  }

  Future<void> _downloadCertificate(
      String imageUrl, String treeName, String treeType) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      final bytes = response.bodyBytes;
      final result = await ImageGallerySaver.saveImage(
        bytes,
        name: '${treeName.replaceAll(' ', '_')}_$treeType',
      );

      if (result['isSuccess']) {
        Fluttertoast.showToast(
          msg: "Saved to Gallery!",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.black,
          textColor: Colors.white,
        );
      } else {
        throw Exception('Failed to save image');
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Failed to download: $e",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: const Color(0xFFB43838),
        textColor: Colors.white,
      );
    }
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
                  builder: (context) => const TabNavigator(initialIndex: 4),
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
            'CERTIFICATES',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: _certificates.isEmpty && !_isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.workspace_premium,
                      size: 100,
                      color: Color(0xFFBDBDBD),
                    ),
                    SizedBox(height: 14),
                    Text(
                      'NOTHING IS HERE',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.only(
                  top: 14,
                  left: 14,
                  right: 14,
                ),
                itemCount: _certificates.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _certificates.length) {
                    return Column(
                      children: [
                        _buildLoadMoreButton(),
                      ],
                    );
                  }
                  final certificate = _certificates[index];
                  return Column(
                    children: [
                      Container(
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
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: ClipRRect(
                                child: Image.network(
                                  certificate['imageUrl'],
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    certificate['treeName'],
                                    style: GoogleFonts.poppins(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    certificate['treeType'],
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _buildActionButton(
                                        icon: Icons.share,
                                        label: 'Share',
                                        onPressed: () => _shareCertificate(
                                          certificate['imageUrl'],
                                          certificate['treeName'],
                                          certificate['treeType'],
                                        ),
                                      ),
                                      _buildActionButton(
                                        icon: Icons.download,
                                        label: 'Download',
                                        onPressed: () => _downloadCertificate(
                                          certificate['imageUrl'],
                                          certificate['treeName'],
                                          certificate['treeType'],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    return _isLoading
        ? const CircularProgressIndicator(
            color: Color(0xFF08DAD6),
            strokeWidth: 6,
          )
        : Padding(
            padding: const EdgeInsets.only(bottom: 14.0),
            child: Column(
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF08DAD6),
                  ),
                  onPressed: _fetchCertificates,
                  child: const Text(
                    'LOAD MORE',
                    style: TextStyle(
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: const Color(0xFF08DAD6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
    );
  }
}
