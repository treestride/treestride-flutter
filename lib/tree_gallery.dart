import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import 'image_view.dart';

class TreePictureUploadPage extends StatefulWidget {
  final String plantRequestId;
  final String treeName;

  const TreePictureUploadPage({
    super.key,
    required this.plantRequestId,
    required this.treeName,
  });

  @override
  TreePictureUploadPageState createState() => TreePictureUploadPageState();
}

class TreePictureUploadPageState extends State<TreePictureUploadPage> {
  List<Map<String, dynamic>> treeImages = [];
  bool isUploading = false;

  @override
  void initState() {
    super.initState();
    _fetchExistingImages();
  }

  Future<void> _fetchExistingImages() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('tree_pictures')
          .where('plantRequestId', isEqualTo: widget.plantRequestId)
          .get();

      setState(() {
        treeImages = querySnapshot.docs
            .map((doc) => {
                  'imageUrl': doc['imageUrl'] as String,
                  'uploadedAt': doc['uploadedAt'] as Timestamp
                })
            .toList();
      });
    } catch (e) {
      _showErrorSnackBar('Error fetching images: $e');
    }
  }

  Future<File> _compressImage(File file) async {
    img.Image? image = img.decodeImage(await file.readAsBytes());
    img.Image resizedImage = img.copyResize(image!, width: 800);
    final directory = await getTemporaryDirectory();
    final compressedFile = File('${directory.path}/compressed_image.jpg');
    await compressedFile.writeAsBytes(img.encodeJpg(resizedImage, quality: 85));
    return compressedFile;
  }

  Future<void> _takePicture() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      setState(() {
        isUploading = true;
      });

      try {
        final compressedFile = await _compressImage(File(pickedFile.path));
        final user = FirebaseAuth.instance.currentUser;
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('tree_pictures')
            .child('${user!.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');

        await storageRef.putFile(compressedFile);
        final imageUrl = await storageRef.getDownloadURL();

        await FirebaseFirestore.instance.collection('tree_pictures').add({
          'plantRequestId': widget.plantRequestId,
          'imageUrl': imageUrl,
          'uploadedBy': user.uid,
          'treeName': widget.treeName,
          'uploadedAt': FieldValue.serverTimestamp(),
        });

        await _fetchExistingImages();
        _showSuccessSnackBar('Image uploaded successfully!');
      } catch (e) {
        _showErrorSnackBar('Error uploading image: $e');
      } finally {
        setState(() {
          isUploading = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showImageOptionsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose Image Source',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildGalleryButton(context),
                _buildCameraButton(context),
              ],
            ),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraButton(BuildContext context) {
    return Column(
      children: [
        IconButton(
          icon: const Icon(Icons.camera_alt, size: 32),
          color: Colors.black,
          onPressed: () {
            Navigator.pop(context);
            _takePicture();
          },
        ),
        Text('Camera', style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }

  Widget _buildGalleryButton(BuildContext context) {
    return Column(
      children: [
        IconButton(
          icon: const Icon(Icons.photo_library, size: 32),
          color: Colors.black,
          onPressed: () {
            Navigator.pop(context);
            _pickImageFromGallery();
          },
        ),
        Text('Gallery', style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }

  Future<void> _pickImageFromGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        isUploading = true;
      });

      try {
        final compressedFile = await _compressImage(File(pickedFile.path));
        final user = FirebaseAuth.instance.currentUser;
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('tree_pictures')
            .child('${user!.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');

        await storageRef.putFile(compressedFile);
        final imageUrl = await storageRef.getDownloadURL();

        await FirebaseFirestore.instance.collection('tree_pictures').add({
          'plantRequestId': widget.plantRequestId,
          'imageUrl': imageUrl,
          'uploadedBy': user.uid,
          'treeName': widget.treeName,
          'uploadedAt': FieldValue.serverTimestamp(),
        });

        await _fetchExistingImages();
        _showSuccessSnackBar('Image uploaded successfully!');
      } catch (e) {
        _showErrorSnackBar('Error uploading image: $e');
      } finally {
        setState(() {
          isUploading = false;
        });
      }
    }
  }

  void _deleteImage(String imageUrl) async {
    try {
      // Find and delete the document with this imageUrl
      final querySnapshot = await FirebaseFirestore.instance
          .collection('tree_pictures')
          .where('imageUrl', isEqualTo: imageUrl)
          .get();

      for (var doc in querySnapshot.docs) {
        await doc.reference.delete();
      }

      // Remove from Firebase Storage
      await FirebaseStorage.instance.refFromURL(imageUrl).delete();

      // Refresh the list
      await _fetchExistingImages();
      _showSuccessSnackBar('Image deleted successfully');
    } catch (e) {
      _showErrorSnackBar('Error deleting image: $e');
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate();
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 2,
        backgroundColor: const Color(0xFFFEFEFE),
        shadowColor: Colors.grey.withOpacity(0.5),
        title: Text(
          '${widget.treeName.toUpperCase()} GALLERY',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          if (isUploading)
            const LinearProgressIndicator(
              backgroundColor: Colors.white,
              color: Color(0xFF08DAD6),
            ),
          Expanded(
            child: treeImages.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_not_supported,
                          size: 100,
                          color: Color(0xFFBDBDBD),
                        ),
                        SizedBox(height: 16),
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
                : GridView.builder(
                    padding: const EdgeInsets.all(14),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: treeImages.length,
                    itemBuilder: (context, index) {
                      return Stack(
                        children: [
                          GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => EnhancedImageViewer(
                                  imageUrl: treeImages[index]['imageUrl'],
                                  uploadedAt: _formatTimestamp(
                                      treeImages[index]['uploadedAt']),
                                ),
                              );
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                image: DecorationImage(
                                  image: NetworkImage(
                                    treeImages[index]['imageUrl'],
                                  ),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 5,
                            right: 5,
                            child: GestureDetector(
                              onTap: () => _deleteImage(
                                treeImages[index]['imageUrl'],
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.7),
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(4),
                                child: const Icon(
                                  Icons.delete,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: () => _showImageOptionsBottomSheet(context),
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Add Picture'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF08DAD6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
