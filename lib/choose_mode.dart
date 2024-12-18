// ignore_for_file: unrelated_type_equality_checks, use_build_context_synchronously

import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'fitness.dart';
import 'environmentalist.dart';
import 'login.dart';
import 'user_data_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ChooseMode());
}

class ChooseMode extends StatelessWidget {
  const ChooseMode({super.key});

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
      home: const ChooseModeHome(),
    );
  }
}

class ChooseModeHome extends StatefulWidget {
  const ChooseModeHome({super.key});

  @override
  State<ChooseModeHome> createState() => _ChooseModeState();
}

class _ChooseModeState extends State<ChooseModeHome> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.storage,
      Permission.activityRecognition,
      Permission.camera,
      Permission.location,
    ].request();
  }

  Future<bool> _checkConnectivity() async {
    try {
      final response = await http
          .head(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  void _navigateToEnvironmentalist() async {
    // Check if the user is from Pangasinan
    final provider = Provider.of<UserDataProvider>(context, listen: false);
    String fromPangasinan = provider.userData?['fromPangasinan'] ?? 'false';

    if (fromPangasinan == 'true') {
      if (await _checkConnectivity()) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const Environmentalist()),
        );
      } else {
        _showToast(
            "You are offline! Please ensure that you are connected to an active internet!");
        return;
      }
    } else {
      // Show a toast or dialog indicating the mode is locked
      _showToast(
          "Sorry! This mode is only available for those users who lives in Pangasinan!");
    }
  }

  Future<void> _initializeApp() async {
    final provider = Provider.of<UserDataProvider>(context, listen: false);
    try {
      await provider.fetchUserData();
      await provider.fetchMissionData();
      await provider.checkMissionStatus();
      await provider.checkMissionCompletion();
      await provider.checkForNewAnnouncements();
      await provider.checkForNewPosts();

      setState(() {
        _isLoading = false;
      });
    } catch (error) {
      _showErrorToast("Initialization error: $error");
      Future.delayed(Duration.zero, () {
        _auth.signOut();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const Login()),
        );
      });
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
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFEFEFEF),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          centerTitle: true,
          title: const Text(
            'CHOOSE MODE',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF08DAD6),
                  strokeWidth: 6.0,
                ), // Show loading indicator
              )
            : Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(children: [
                      Column(
                        children: [
                          GestureDetector(
                            onTap: () => {
                              _navigateToEnvironmentalist(),
                            },
                            child: ClipRRect(
                              child: Image.asset(
                                "assets/images/planting.png",
                                height: 200,
                                width: 200,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            "ENVIRONMENTALIST",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 48),
                      Column(
                        children: [
                          GestureDetector(
                            onTap: () => {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const Fitness(),
                                ),
                              ),
                            },
                            child: ClipRRect(
                              child: Image.asset(
                                "assets/images/fitness.png",
                                height: 200,
                                width: 200,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            "FITNESS ENTHUSIAST",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        ],
                      ),
                    ]),
                  ),
                ),
              ),
      ),
    );
  }
}
