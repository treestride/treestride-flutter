// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:treestride/offline.dart';

import 'create_edit.dart';
import 'home.dart';
import 'leaderboard.dart';
import 'plant_tree.dart';
import 'profile.dart';
import 'user_data_provider.dart';

class UserFeedPage extends StatefulWidget {
  const UserFeedPage({super.key});

  @override
  UserFeedPageState createState() => UserFeedPageState();
}

class UserFeedPageState extends State<UserFeedPage>
    with WidgetsBindingObserver {
  late Stream<List<ConnectivityResult>> _connectivityStream;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final List<DocumentSnapshot> _posts = [];
  bool _isLoading = false;
  bool _hasMorePosts = true;
  DocumentSnapshot? _lastDocument;
  static const int _postsPerPage = 5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connectivityStream = Connectivity().onConnectivityChanged;
    _checkConnection();
    _loadPosts();
    _postViewed();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      _postViewed();
    }
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

  Future<void> _postViewed() async {
    Provider.of<UserDataProvider>(context, listen: false)
        .updateLastPostViewTime();
  }

  Future<void> _loadPosts() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    Query query = _firestore
        .collection('posts')
        .orderBy('timestamp', descending: true)
        .limit(_postsPerPage);

    if (_lastDocument != null) {
      query = query.startAfterDocument(_lastDocument!);
    }

    QuerySnapshot querySnapshot = await query.get();
    if (querySnapshot.docs.isNotEmpty) {
      setState(() {
        _posts.addAll(querySnapshot.docs);
        _lastDocument = querySnapshot.docs.last;
        _hasMorePosts = querySnapshot.docs.length >= _postsPerPage;
        _isLoading = false;
      });
    } else {
      setState(() {
        _hasMorePosts = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _createPost(String text, File? image, String? username) async {
    final userDataProvider =
        Provider.of<UserDataProvider>(context, listen: false);
    final userData = userDataProvider.userData;
    String? imageUrl;

    if (image != null) {
      // Compress the image
      final dir = await path_provider.getTemporaryDirectory();
      final targetPath = path.join(
          dir.absolute.path, "${DateTime.now().millisecondsSinceEpoch}.jpg");
      var result = await FlutterImageCompress.compressAndGetFile(
        image.absolute.path,
        targetPath,
        quality: 88,
      );

      if (result != null) {
        String fileName = DateTime.now().millisecondsSinceEpoch.toString();
        Reference storageRef =
            FirebaseStorage.instance.ref().child('post_images/$fileName');

        // Convert XFile to File
        File compressedFile = File(result.path);

        UploadTask uploadTask = storageRef.putFile(compressedFile);
        TaskSnapshot taskSnapshot = await uploadTask;
        imageUrl = await taskSnapshot.ref.getDownloadURL();
      }
    }

    await _firestore.collection('posts').add({
      'userId': _auth.currentUser!.uid,
      'username': userData!["username"],
      'photoURL': userData["photoURL"],
      'text': text,
      'imageUrl': imageUrl,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Refresh the feed
    setState(() {
      _posts.clear();
      _lastDocument = null;
    });
    _loadPosts();
  }

  Future<void> _editPost(
      String postId, String newText, File? newImage, String? username) async {
    String? imageUrl;

    if (newImage != null) {
      // Compress the image
      final dir = await path_provider.getTemporaryDirectory();
      final targetPath = path.join(
          dir.absolute.path, "${DateTime.now().millisecondsSinceEpoch}.jpg");
      var result = await FlutterImageCompress.compressAndGetFile(
        newImage.absolute.path,
        targetPath,
        quality: 88,
      );

      if (result != null) {
        String fileName = DateTime.now().millisecondsSinceEpoch.toString();
        Reference storageRef =
            FirebaseStorage.instance.ref().child('post_images/$fileName');

        // Convert XFile to File
        File compressedFile = File(result.path);

        UploadTask uploadTask = storageRef.putFile(compressedFile);
        TaskSnapshot taskSnapshot = await uploadTask;
        imageUrl = await taskSnapshot.ref.getDownloadURL();
      }
    }

    Map<String, dynamic> updateData = {
      'text': newText,
      'editedAt': FieldValue.serverTimestamp(),
      'username': username,
    };

    if (imageUrl != null) {
      updateData['imageUrl'] = imageUrl;
    }

    await _firestore.collection('posts').doc(postId).update(updateData);

    // Refresh the feed
    setState(() {
      _posts.clear();
      _lastDocument = null;
    });
    _loadPosts();
  }

  Future<void> _deletePost(String postId) async {
    await _firestore.collection('posts').doc(postId).delete();

    // Refresh the feed
    setState(() {
      _posts.clear();
      _lastDocument = null;
    });
    _loadPosts();
  }

  Widget _buildPostItem(DocumentSnapshot post) {
    Map<String, dynamic> postData = post.data() as Map<String, dynamic>;
    bool isCurrentUserPost = postData['userId'] == _auth.currentUser!.uid;
    DateTime timestamp = (postData['timestamp'] as Timestamp).toDate();
    String formattedDate = DateFormat.yMMMd().add_jm().format(timestamp);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.black12,
                    child: CircleAvatar(
                      radius: 22,
                      backgroundImage: CachedNetworkImageProvider(
                        postData["photoURL"] ?? '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    postData['username'] ?? '',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],
          ),
          postData['text'] != ''
              ? Padding(
                  padding: const EdgeInsets.only(
                    left: 8,
                    bottom: 8,
                    right: 8,
                  ),
                  child: Text(
                    postData['text'] ?? '',
                    style: const TextStyle(fontSize: 16),
                  ),
                )
              : const SizedBox.shrink(),
          postData['imageUrl'] != null
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: GestureDetector(
                    onTap: () => _showImageDialog(postData['imageUrl']),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: CachedNetworkImage(
                        imageUrl: postData['imageUrl'],
                        fit: BoxFit.contain,
                        width: double.infinity,
                        placeholder: (context, url) => const Padding(
                          padding: EdgeInsets.all(14.0),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF08DAD6),
                              strokeWidth: 6,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.error),
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
          Center(
            child: Text(
              formattedDate,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
          if (isCurrentUserPost)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF08DAD6),
                      surfaceTintColor: const Color(0xFF08DAD6),
                    ),
                    icon: const Icon(Icons.edit),
                    label: const Text(
                      'Edit',
                      style: TextStyle(
                        color: Colors.black,
                      ),
                    ),
                    onPressed: () => _navigateToEditPost(
                        post.id,
                        postData['text'],
                        postData['imageUrl'],
                        postData['username']),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFB43838),
                      surfaceTintColor: const Color(0xFFB43838),
                    ),
                    icon: const Icon(Icons.delete, size: 18),
                    label: const Text(
                      'Delete',
                      style: TextStyle(
                        color: Colors.black,
                      ),
                    ),
                    onPressed: () => _showDeleteConfirmation(post.id),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showImageDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Center(child: Text('Save Image?')),
          actionsAlignment: MainAxisAlignment.spaceAround,
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF08DAD6),
                surfaceTintColor: const Color(0xFF08DAD6),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF08DAD6),
                surfaceTintColor: const Color(0xFF08DAD6),
              ),
              child: const Text(
                'Save',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _saveImage(imageUrl);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveImage(String imageUrl) async {
    // Request storage permission
    var status = await Permission.storage.request();

    if (status.isGranted) {
      try {
        // Download the image
        var response = await http.get(Uri.parse(imageUrl));
        final result = await ImageGallerySaver.saveImage(
            Uint8List.fromList(response.bodyBytes),
            quality: 60,
            name: "treestride_${DateTime.now().millisecondsSinceEpoch}.jpg");

        if (result['isSuccess']) {
          Fluttertoast.showToast(
            msg: "Image Downloaded!",
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
          msg: "Error Saving!",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.black,
          textColor: Colors.white,
        );
      }
    } else {
      Fluttertoast.showToast(
        msg: "No Permission!",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.black,
        textColor: Colors.white,
      );
    }
  }

  void _showDeleteConfirmation(String postId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          textAlign: TextAlign.center,
          'Delete Post',
          style: TextStyle(
            fontSize: 24,
            color: Colors.black,
          ),
        ),
        content: const Text(
          textAlign: TextAlign.center,
          'Are you sure you want to delete this post?',
        ),
        actionsAlignment: MainAxisAlignment.spaceAround,
        actions: [
          TextButton(
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Colors.black,
              ),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB43838),
              foregroundColor: const Color(0xFFB43838),
              surfaceTintColor: const Color(0xFFB43838),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
              ),
            ),
            onPressed: () {
              _deletePost(postId);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _navigateToCreatePost() async {
    final userDataProvider =
        Provider.of<UserDataProvider>(context, listen: false);
    final userData = userDataProvider.userData;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateEditPostPage(
          username: userData!["username"],
          onSave: (text, image, username) async {
            await _createPost(text, image, username);
          },
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _posts.clear();
        _lastDocument = null;
      });
      _loadPosts();
    }
  }

  void _navigateToEditPost(String postId, String currentText,
      String? currentImageUrl, String username) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateEditPostPage(
          initialText: currentText,
          initialImageUrl: currentImageUrl,
          username: username,
          onSave: (text, image, username) async {
            await _editPost(postId, text, image, username);
          },
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _posts.clear();
        _lastDocument = null;
      });
      _loadPosts();
    }
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
          _postViewed();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const Home(),
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
                _postViewed();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const Home(),
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
              'TREESTRIDE',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              IconButton(
                onPressed: _navigateToCreatePost,
                icon: const Icon(Icons.edit_document),
              )
            ],
          ),
          bottomNavigationBar: Container(
            padding: const EdgeInsets.symmetric(vertical: 10.0),
            decoration: BoxDecoration(
              color: const Color(0xFFFEFEFE),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 2,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                Stack(
                  children: [
                    GestureDetector(
                      onTap: () {},
                      child: const Icon(
                        Icons.space_dashboard_outlined,
                        size: 30,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    _postViewed();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const Leaderboard(),
                      ),
                    );
                  },
                  child: const Icon(
                    Icons.emoji_events_outlined,
                    size: 30,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    _postViewed();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const Home(),
                      ),
                    );
                  },
                  child: const Icon(
                    Icons.directions_walk_outlined,
                    size: 30,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    _postViewed();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TreeShop(),
                      ),
                    );
                  },
                  child: const Icon(
                    Icons.park_outlined,
                    size: 30,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    _postViewed();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const Profile(),
                      ),
                    );
                  },
                  child: const Icon(
                    Icons.perm_identity_outlined,
                    size: 30,
                  ),
                ),
              ],
            ),
          ),
          body: _isLoading && _posts.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF08DAD6),
                    strokeWidth: 6.0,
                  ),
                )
              : _posts.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.post_add,
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
                  : RefreshIndicator(
                      color: const Color(0xFF08DAD6),
                      onRefresh: () async {
                        setState(() {
                          _posts.clear();
                          _lastDocument = null;
                        });
                        await _loadPosts();
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.only(
                          top: 24,
                          left: 24,
                          right: 24,
                        ),
                        itemCount: _posts.length + (_hasMorePosts ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index < _posts.length) {
                            return Column(
                              children: [
                                _buildPostItem(_posts[index]),
                                const SizedBox(height: 24)
                              ],
                            );
                          } else if (_isLoading) {
                            return const Column(
                              children: [
                                Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF08DAD6),
                                    strokeWidth: 6.0,
                                  ),
                                ),
                                SizedBox(height: 24)
                              ],
                            );
                          } else {
                            return Column(
                              children: [
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF08DAD6),
                                  ),
                                  onPressed: _loadPosts,
                                  child: const Text(
                                    'Load More',
                                    style: TextStyle(
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24)
                              ],
                            );
                          }
                        },
                      ),
                    ),
        ),
      ),
    );
  }
}
