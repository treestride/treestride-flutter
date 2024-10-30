// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'choose_mode.dart';
import 'forgot_password.dart';
import 'register.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends State<Login> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String _email = '';
  String _password = '';

  InputDecoration _inputDecoration(String label) {
    IconData suffixIconData;
    VoidCallback? onPressed;

    switch (label) {
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

  String _getFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided for that user.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This user has been disabled.';
      default:
        return e.message ?? 'An unknown error occurred. Please try again.';
    }
  }

  void _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      _formKey.currentState!.save();
      try {
        UserCredential userCredential = await _auth.signInWithEmailAndPassword(
            email: _email, password: _password);

        User user = userCredential.user!;

        await user.reload();
        user = _auth.currentUser!;

        if (!user.emailVerified) {
          _showEmailVerificationPrompt(user);
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const ChooseMode(),
            ),
          );
        }
      } on FirebaseAuthException catch (e) {
        _showToast(_getFirebaseAuthError(e));
      } catch (e) {
        _showErrorToast('An error occurred. Please try again.');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showEmailVerificationPrompt(User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          textAlign: TextAlign.center,
          'EMAIL NOT VERIFIED',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          textAlign: TextAlign.center,
          'Please verify your email to continue. A verification email has been sent to ${user.email}.',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceAround,
        actions: [
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () async {
                await user.sendEmailVerification();
                _showToast(
                    'Verification email resent. Please check your inbox.');
              },
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF08DAD6),
              ),
              child: const Text(
                'RESEND LINK',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF08DAD6),
              ),
              child: const Text(
                "CANCEL",
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
    );
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
        textTheme: GoogleFonts.exo2TextTheme(Theme.of(context).textTheme),
        primaryTextTheme:
            GoogleFonts.exoTextTheme(Theme.of(context).primaryTextTheme),
      ),
      home: PopScope(
        canPop: false,
        onPopInvoked: (didPop) {
          SystemNavigator.pop();
        },
        child: Scaffold(
          body: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset("assets/images/logo.png"),
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            TextFormField(
                              cursorColor: const Color(0xFF08DAD6),
                              keyboardType: TextInputType.emailAddress,
                              decoration: _inputDecoration('Email'),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your email';
                                }
                                return null;
                              },
                              onChanged: (value) {
                                _email = value;
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              cursorColor: const Color(0xFF08DAD6),
                              keyboardType: TextInputType.text,
                              decoration: _inputDecoration('Password'),
                              obscureText: _obscurePassword,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your password';
                                }
                                return null;
                              },
                              onChanged: (value) {
                                _password = value;
                              },
                            ),
                            const SizedBox(height: 4),
                            Container(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                style: TextButton.styleFrom(
                                    padding: const EdgeInsets.all(0)),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const ForgotPassword(),
                                    ),
                                  );
                                },
                                child: const Text(
                                  'Forgot Password?',
                                  style: TextStyle(
                                    color: Color.fromARGB(255, 0, 110, 255),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  backgroundColor: const Color(0xFF08DAD6),
                                ),
                                onPressed: _login,
                                child: const Text(
                                  'LOGIN',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const Register(),
                                  ),
                                );
                              },
                              child: const Text(
                                'CREATE NEW ACCOUNT',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color.fromARGB(255, 0, 110, 255),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
      ),
    );
  }
}
