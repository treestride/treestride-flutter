// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:provider/provider.dart';

import 'user_data_provider.dart';

class EditProfile extends StatefulWidget {
  const EditProfile({super.key});

  @override
  EditProfileHomeState createState() => EditProfileHomeState();
}

class EditProfileHomeState extends State<EditProfile> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String _username = '';
  String _phoneNumber = '';
  String _currentPhotoURL = '';
  File? _newImage;
  bool _isLoading = false;
  bool _isCheckingUsername = false;
  String? _usernameError;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final userData =
            await _firestore.collection('users').doc(user.uid).get();
        setState(() {
          _username = userData.get('username');
          _phoneNumber = userData.get('phoneNumber');
          _currentPhotoURL = userData.get('photoURL');
        });
      }
    } catch (e) {
      _showMessage('Error loading user data: $e', isError: true);
    }
    setState(() => _isLoading = false);
  }

  Future<bool> _isUsernameUnique(String username) async {
    if (username.toLowerCase() == _username.toLowerCase()) {
      return true; // Username hasn't changed
    }

    String lowercaseUsername = username.toLowerCase();
    final QuerySnapshot result = await _firestore
        .collection('users')
        .where('lowercaseUsername', isEqualTo: lowercaseUsername)
        .limit(1)
        .get();
    return result.docs.isEmpty;
  }

  Future<String?> _validateUsername(String? value) async {
    if (value == null || value.isEmpty) {
      return 'Please enter your username';
    }
    if (value.length > 8) {
      return 'Username must be 8 characters or less';
    }
    if (value != _username) {
      setState(() => _isCheckingUsername = true);
      bool isUnique = await _isUsernameUnique(value);
      setState(() => _isCheckingUsername = false);
      if (!isUnique) {
        return 'This username is already taken';
      }
    }
    return null;
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        File? croppedFile = await _cropImage(File(pickedFile.path));
        setState(() {
          _newImage = croppedFile;
        });
      }
    } catch (e) {
      _showMessage('Failed to pick image: $e');
    }
  }

  Future<File?> _cropImage(File imageFile) async {
    CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: imageFile.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'CROP PICTURE',
          toolbarColor: const Color(0xFF08DAD6),
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: false,
        ),
      ],
    );

    if (croppedFile != null) {
      return File(croppedFile.path);
    }
    return null;
  }

  Future<String> _uploadImage(File image) async {
    try {
      final ref =
          _storage.ref().child('profile_pictures/${DateTime.now()}.png');
      final uploadTask = await ref.putFile(image);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      _showMessage('Error uploading image: $e');
      return '';
    }
  }

  String? _validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your phone number';
    }

    String cleanNumber = value.replaceAll(RegExp(r'\s+'), '');

    if (cleanNumber.startsWith('+639')) {
      if (cleanNumber.length != 13) {
        return 'Phone number must be 13 digits long with +639';
      }
      if (!RegExp(r'^\+639\d{9}$').hasMatch(cleanNumber)) {
        return 'Invalid Philippine phone number format';
      }
    } else if (cleanNumber.startsWith('09')) {
      if (cleanNumber.length != 11) {
        return 'Phone number must be 11 digits long';
      }
      if (!RegExp(r'^09\d{9}$').hasMatch(cleanNumber)) {
        return 'Invalid Philippine phone number format';
      }
    } else {
      return 'Phone number must start with 09 or +639';
    }

    return null;
  }

  Future<void> _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      String? usernameError = await _validateUsername(_username);
      if (usernameError != null) {
        setState(() => _usernameError = usernameError);
        return;
      }

      setState(() => _isLoading = true);

      try {
        final user = _auth.currentUser;
        if (user != null) {
          Map<String, dynamic> updateData = {
            'username': _username,
            'lowercaseUsername': _username.toLowerCase(),
            'phoneNumber': _phoneNumber,
          };

          String photoURL = _currentPhotoURL;
          if (_newImage != null) {
            String newPhotoURL = await _uploadImage(_newImage!);
            if (newPhotoURL.isNotEmpty) {
              updateData['photoURL'] = newPhotoURL;
              photoURL = newPhotoURL;
              if (_currentPhotoURL.isNotEmpty) {
                try {
                  await _storage.refFromURL(_currentPhotoURL).delete();
                } catch (e) {
                  _showMessage('Error deleting old photo: $e');
                }
              }
            }
          }

          // Update Firestore
          await _firestore.collection('users').doc(user.uid).update(updateData);

          // Update all posts by this user
          final userPosts = await _firestore
              .collection('posts')
              .where('userId', isEqualTo: user.uid)
              .get();

          final batch = _firestore.batch();
          for (var doc in userPosts.docs) {
            batch.update(doc.reference, {
              'username': _username,
              'photoURL': photoURL,
            });
          }
          await batch.commit();

          // Notify UserDataProvider
          if (!mounted) return;
          Provider.of<UserDataProvider>(context, listen: false)
              .updateUserProfile(_username, photoURL);

          _showMessage('Profile updated!');
          Navigator.of(context).pop();
        }
      } catch (e) {
        _showMessage('Error updating profile: $e', isError: true);
      }

      setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: isError ? const Color(0xFFB43838) : Colors.black,
      textColor: Colors.white,
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.black, fontSize: 14),
      floatingLabelStyle: const TextStyle(color: Color(0xFF08DAD6)),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFF08DAD6), width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFF08DAD6), width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFFB43838), width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFF08DAD6), width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      suffixIcon: Icon(
        label == 'Username' ? Icons.person : Icons.phone,
        color: const Color(0xFF08DAD6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFEFEF),
      appBar: AppBar(
        elevation: 2,
        backgroundColor: const Color(0xFFFEFEFE),
        shadowColor: Colors.grey.withOpacity(0.5),
        leading: IconButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.arrow_back),
          iconSize: 24,
        ),
        centerTitle: true,
        title: const Text(
          'EDIT PROFILE',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: _isLoading
              ? const CircularProgressIndicator(
                  color: Color(0xFF08DAD6),
                  strokeWidth: 6.0,
                )
              : Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _pickImage,
                          child: CircleAvatar(
                            radius: 64,
                            backgroundColor: const Color(0xFF08DAD6),
                            child: CircleAvatar(
                              radius: 62,
                              backgroundColor: Colors.grey[200],
                              backgroundImage: _newImage != null
                                  ? FileImage(_newImage!)
                                  : (_currentPhotoURL.isNotEmpty
                                      ? NetworkImage(_currentPhotoURL)
                                      : null) as ImageProvider?,
                              child:
                                  _newImage == null && _currentPhotoURL.isEmpty
                                      ? Icon(
                                          Icons.add_a_photo,
                                          size: 48,
                                          color: Colors.grey[700],
                                        )
                                      : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          initialValue: _username,
                          decoration: _inputDecoration('Username'),
                          onChanged: (value) async {
                            _username = value;
                            _usernameError = await _validateUsername(value);
                            setState(() {});
                          },
                          validator: (value) => value == null || value.isEmpty
                              ? 'Please enter your username'
                              : null,
                        ),
                        if (_isCheckingUsername)
                          const Padding(
                            padding: EdgeInsets.only(top: 8.0),
                            child: Text('Checking username availability...'),
                          )
                        else if (_usernameError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              _usernameError!,
                              style: const TextStyle(color: Color(0xFFB43838)),
                            ),
                          ),
                        const SizedBox(height: 14),
                        TextFormField(
                          initialValue: _phoneNumber,
                          decoration: _inputDecoration('Phone Number'),
                          keyboardType: TextInputType.phone,
                          validator: _validatePhoneNumber,
                          onChanged: (value) => _phoneNumber = value,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9+]')),
                            LengthLimitingTextInputFormatter(13),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              backgroundColor: const Color(0xFF08DAD6),
                            ),
                            onPressed: _updateProfile,
                            child: const Text(
                              'SAVE CHANGES',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
