// ignore_for_file: use_build_context_synchronously, unused_field

import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'email_verification.dart';

class Register extends StatefulWidget {
  const Register({super.key});

  @override
  RegisterPageState createState() => RegisterPageState();
}

class RegisterPageState extends State<Register> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String _email = '',
      _password = '',
      _confirmPassword = '',
      _username = '',
      _phoneNumber = '';
  File? _image;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<bool> _isUsernameUnique(String username) async {
    final QuerySnapshot result = await _firestore
        .collection('users')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();
    return result.docs.isEmpty;
  }

  String? _usernameError;
  bool _isCheckingUsername = false;

  Future<String?> _validateUsername(String? value) async {
    if (value == null || value.isEmpty) {
      return 'Please enter your username';
    }
    if (value.length > 8) {
      return 'Username must be 8 characters or less';
    }
    setState(() => _isCheckingUsername = true);
    bool isUnique = await _isUsernameUnique(value);
    setState(() => _isCheckingUsername = false);
    if (!isUnique) {
      return 'This username is already taken';
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
          _image = croppedFile;
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
          toolbarTitle: 'Crop Profile Picture',
          toolbarColor: const Color(0xFF08DAD6),
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: false,
          aspectRatioPresets: [
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9
          ],
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

  String _hashPassword(String password) {
    var bytes = utf8.encode(password); // Convert the password to bytes
    var digest = sha256.convert(bytes); // Hash the bytes
    return digest.toString(); // Return the hashed password as a string
  }

  void _register() async {
    if (_formKey.currentState!.validate()) {
      String? usernameError = await _validateUsername(_username);
      if (usernameError != null) {
        setState(() => _usernameError = usernameError);
        return;
      }
      if (_image == null) {
        _showMessage("Please select an image", isError: true);
        return;
      }

      setState(() {
        _isLoading = true;
      });

      _formKey.currentState!.save();

      try {
        UserCredential userCredential =
            await _auth.createUserWithEmailAndPassword(
          email: _email,
          password: _password,
        );

        await userCredential.user!.sendEmailVerification();

        String photoURL = await _uploadImage(_image!);
        String hashedPassword = _hashPassword(_password);

        final defaultEndDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

        await _firestore.collection('users').doc(userCredential.user!.uid).set(
          {
            'photoURL': photoURL,
            'username': _username,
            'email': _email,
            'password': hashedPassword,
            'phoneNumber': _phoneNumber,
            'totalPoints': '0',
            'totalSteps': '0',
            'missionSteps': '0',
            'walkingSteps': '0',
            'walkingGoal': '0',
            'walkingGoalEndDate': defaultEndDate,
            'isWalkingGoalActive': 'false',
            'joggingSteps': '0',
            'joggingGoal': '0',
            'joggingGoalEndDate': defaultEndDate,
            'isJoggingGoalActive': 'false',
            'runningSteps': '0',
            'runningGoal': '0',
            'runningGoalEndDate': defaultEndDate,
            'isRunningGoalActive': 'false',
            'missionsCompleted': '0',
            'totalTrees': '0',
            'certificates': '0',
            'isMissionCompleted': 'false',
            'lastAnnouncementViewTime': Timestamp.fromDate(DateTime(2000)),
            'lastPostViewTime': Timestamp.fromDate(DateTime(2000)),
          },
        );

        // Navigate to the email verification page
        if (context.mounted) {
          Navigator.of(context).pop();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => EmailVerificationPage(user: userCredential.user!),
            ),
          );
        }
      } on FirebaseAuthException catch (e) {
        _showMessage(_getFirebaseError(e), isError: true);
      } catch (e) {
        _showMessage('An error occurred: $e', isError: true);
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'The email address is already in use.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'weak-password':
        return 'The password is too weak.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      default:
        return 'An unknown error occurred. Please try again.';
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
    IconData suffixIconData;
    VoidCallback? onPressed;

    switch (label) {
      case 'Username':
        suffixIconData = Icons.person;
        break;
      case 'Phone Number':
        suffixIconData = Icons.phone;
        break;
      case 'Email':
        suffixIconData = Icons.email;
        break;
      case 'Password':
        suffixIconData =
            _obscurePassword ? Icons.visibility_off : Icons.visibility;
        onPressed = () {
          setState(() {
            _obscurePassword = !_obscurePassword;
          });
        };
        break;
      case 'Confirm Password':
        suffixIconData =
            _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility;
        onPressed = () {
          setState(() {
            _obscureConfirmPassword = !_obscureConfirmPassword;
          });
        };
        break;
      default:
        suffixIconData = Icons.edit;
    }

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
      suffixIcon: IconButton(
        icon: Icon(
          suffixIconData,
          color: const Color(0xFF08DAD6),
        ),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildUsernameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
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
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        textTheme: GoogleFonts.exo2TextTheme(Theme.of(context).textTheme),
        primaryTextTheme:
            GoogleFonts.exoTextTheme(Theme.of(context).primaryTextTheme),
      ),
      home: Scaffold(
        body: Stack(
          children: [
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Image.asset("assets/images/logo.png"),
                      GestureDetector(
                        onTap: _pickImage,
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: const Color(0xFF08DAD6),
                          child: CircleAvatar(
                            radius: 48,
                            backgroundColor: Colors.grey[200],
                            backgroundImage:
                                _image != null ? FileImage(_image!) : null,
                            child: _image == null
                                ? Icon(
                                    Icons.add_a_photo,
                                    size: 48,
                                    color: Colors.grey[700],
                                  )
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_image == null)
                        const Text(
                          'Please select a profile image.',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 12,
                          ),
                        ),
                      const SizedBox(height: 14),
                      _buildUsernameField(),
                      const SizedBox(height: 14),
                      TextFormField(
                        decoration: _inputDecoration('Phone Number'),
                        keyboardType: TextInputType.phone,
                        validator: (value) => value == null || value.isEmpty
                            ? 'Please enter your phone number'
                            : null,
                        onChanged: (value) => _phoneNumber = value,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        decoration: _inputDecoration('Email'),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          String pattern =
                              r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
                          return !RegExp(pattern).hasMatch(value)
                              ? 'Please enter a valid email address'
                              : null;
                        },
                        onChanged: (value) => _email = value,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        decoration: _inputDecoration('Password'),
                        obscureText: _obscurePassword,
                        validator: (value) => value == null || value.isEmpty
                            ? 'Please enter your password'
                            : (value.length < 6
                                ? 'Password must be at least 6 characters long'
                                : null),
                        onChanged: (value) => _password = value,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        decoration: _inputDecoration('Confirm Password'),
                        obscureText: _obscureConfirmPassword,
                        validator: (value) => value == null || value.isEmpty
                            ? 'Please confirm your password'
                            : (value != _password
                                ? 'Passwords do not match'
                                : null),
                        onChanged: (value) => _confirmPassword = value,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
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
                          onPressed: _register,
                          child: const Text(
                            'REGISTER',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Already have an account?",
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'Login Instead',
                              style: TextStyle(
                                color: Color.fromARGB(255, 0, 110, 255),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_isLoading)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF08DAD6),
                    strokeWidth: 6.0,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
