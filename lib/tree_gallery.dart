import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

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
                  'uploadedAt': doc['uploadedAt'] as Timestamp,
                  'locationName': doc['locationName'] as String?,
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
        // Get the current location
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
        );

        String locationName = await _getAccurateLocationName(position);

        // Compress and upload the image
        final compressedFile = await _compressImage(File(pickedFile.path));
        final user = FirebaseAuth.instance.currentUser;
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('tree_pictures')
            .child('${user!.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');

        await storageRef.putFile(compressedFile);
        final imageUrl = await storageRef.getDownloadURL();

        // Save image details and location to Firestore
        await FirebaseFirestore.instance.collection('tree_pictures').add({
          'plantRequestId': widget.plantRequestId,
          'imageUrl': imageUrl,
          'uploadedBy': user.uid,
          'treeName': widget.treeName,
          'uploadedAt': FieldValue.serverTimestamp(),
          'locationName': locationName,
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

  Future<String> _getAccurateLocationName(Position position) async {
    try {
      // Try geocoding first
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        String detailedAddress = '${place.locality ?? ''}, '
            '${place.subAdministrativeArea ?? ''}, '
            '${place.country ?? ''}';

        // Remove any empty segments and trim
        detailedAddress = detailedAddress
            .split(',')
            .where((segment) => segment.trim().isNotEmpty)
            .join(', ')
            .trim();

        return detailedAddress.isNotEmpty
            ? detailedAddress
            : 'Unknown Location';
      }
    } catch (e) {
      _showErrorSnackBar('Location capture error: $e');
    }

    return 'Unknown Location';
  }

  void _deleteImage(String imageUrl) async {
    // Show confirmation dialog before deleting
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        actionsAlignment: MainAxisAlignment.spaceAround,
        title: const Text(
          'Delete Image',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            color: Colors.black,
          ),
        ),
        content: const Text(
          'Are you sure you want to delete this image?',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.black)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFB43838),
              foregroundColor: const Color(0xFFB43838),
              surfaceTintColor: const Color(0xFFB43838),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    // Only proceed with deletion if user confirms
    if (confirmDelete == true) {
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
  }

  Future<void> _postImage(String imageUrl) async {
    // Create a text controller for the caption input
    final TextEditingController captionController = TextEditingController();

    // Show dialog with caption input
    bool? confirmPost = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Post Image',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            color: Colors.black,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              maxLines: 3,
              controller: captionController,
              decoration: InputDecoration(
                hintText: 'Have something to say? (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(
                    color: Color(0xFF08DAD6),
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(
                    color: Color(0xFF08DAD6),
                    width: 1,
                  ),
                ),
              ),
              maxLength: 200,
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceAround,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.black)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF08DAD6),
              foregroundColor: const Color(0xFF08DAD6),
              surfaceTintColor: const Color(0xFF08DAD6),
            ),
            child: const Text(
              'Post',
              style: TextStyle(
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    // Only proceed with posting if user confirms
    if (confirmPost == true) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw 'User not authenticated';

        final userData = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        // Use caption if provided, otherwise default to tree name
        String postText = captionController.text.trim().isEmpty
            ? '${widget.treeName} picture'
            : captionController.text.trim();

        await FirebaseFirestore.instance.collection('posts').add({
          'userId': user.uid,
          'username': userData['username'],
          'photoURL': userData['photoURL'],
          'text': postText,
          'imageUrl': imageUrl,
          'timestamp': FieldValue.serverTimestamp(),
          'isReported': false,
          'likes': [],
        });

        _showSuccessSnackBar('Image posted successfully!');
      } catch (e) {
        _showErrorSnackBar('Error posting image: $e');
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
            fontSize: 20,
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
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
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
                                  locationName: treeImages[index]
                                      ['locationName'],
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
                          Positioned(
                            bottom: 5,
                            right: 5,
                            child: GestureDetector(
                              onTap: () =>
                                  _postImage(treeImages[index]['imageUrl']),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.7),
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(4),
                                child: const Icon(
                                  Icons.send,
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
            padding: const EdgeInsets.all(14.0),
            child: ElevatedButton.icon(
              onPressed: () => _takePicture(),
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
