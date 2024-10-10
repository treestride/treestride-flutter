import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'fitness.dart';
import 'environmentalist.dart';
import 'login.dart';
import 'offline.dart';
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
  late Stream<List<ConnectivityResult>> _connectivityStream;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });

    _connectivityStream = Connectivity().onConnectivityChanged;
    _checkConnection();
    //_requestPermissions();
  }
/*
  Future<void> _requestPermissions() async {
    await [
      Permission.storage,
      Permission.activityRecognition,
      Permission.camera
    ].request();
  }
*/

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

  Future<void> _initializeApp() async {
    final provider = Provider.of<UserDataProvider>(context, listen: false);
    try {
      await provider.fetchUserData();
      await provider.fetchMissionData();
      await provider.checkMissionCompletion();
      await provider.checkForNewAnnouncements();
      await provider.checkForNewPosts();
      await provider.initNotifications();
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
        body: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(children: [
                Column(
                  children: [
                    GestureDetector(
                      onTap: () => {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const Home(),
                          ),
                        ),
                      },
                      child: ClipRRect(
                        child: Image.asset(
                          "images/planting.png",
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
                          "images/fitness.png",
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
