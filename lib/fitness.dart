// ignore_for_file: unrelated_type_equality_checks, use_build_context_synchronously

import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'announcements.dart';
import 'bottom_navigation_fitness.dart';
import 'environmentalist.dart';
import 'jogging_fitness.dart';
import 'login.dart';
import 'running_fitness.dart';
import 'user_data_provider.dart';
import 'walking_fitness.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Fitness());
}

class Fitness extends StatelessWidget {
  const Fitness({super.key});

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
      home: const FitnessContent(),
    );
  }
}

// Create a new FitnessContent widget to hold the main content
class FitnessContent extends StatelessWidget {
  const FitnessContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const TabNavigatorFitness();
  }
}

class FitnessMode extends StatefulWidget {
  const FitnessMode({super.key});

  @override
  State<FitnessMode> createState() => FitnessState();
}

class FitnessState extends State<FitnessMode> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late SharedPreferences _prefs;
  int _totalSteps = 0;

  @override
  void initState() {
    super.initState();
    _initializeApp();
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
    if (await _checkConnectivity()) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Environmentalist()),
      );
    } else {
      _showToast("You are offline!");
      return;
    }
  }

  void _navigateToAnnouncements() async {
    if (await _checkConnectivity()) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const AnnouncementPage(
            previousPage: Fitness(),
          ),
        ),
      );
    } else {
      _showToast("You are offline!");
      return;
    }
  }

  Future<void> _initializeApp() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _totalSteps = _prefs.getInt('totalSteps') ?? 0;
      setState(() {});
    } catch (error) {
      _showErrorToast("Initialization error: $error");
      if (mounted) {
        _auth.signOut();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const Login(),
          ),
        );
      }
    }
  }

  void _showUserProfile(UserDataProvider userDataProvider) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Container(
            height: 300,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 64,
                  backgroundColor: Colors.black12,
                  child: CircleAvatar(
                    radius: 62,
                    backgroundImage: CachedNetworkImageProvider(
                      userDataProvider.userData!['photoURL'] ?? 'N/A',
                    ),
                    onBackgroundImageError: (error, stackTrace) => const Icon(
                      Icons.image,
                      size: 64,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  userDataProvider.userData!['username'] ?? 'N/A',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF08DAD6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    _auth.signOut();
                    Navigator.of(context).pop();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const Login(),
                      ),
                    );
                  },
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Sign Out",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.logout,
                        color: Colors.black,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF08DAD6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _navigateToEnvironmentalist();
                  },
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Switch Mode",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.shuffle,
                        color: Colors.black,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
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

  void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black,
      textColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserDataProvider>(
      builder: (context, userDataProvider, child) {
        if (userDataProvider.userData == null) {
          return const Scaffold(
            backgroundColor: Color(0xFFEFEFEF),
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF08DAD6),
                strokeWidth: 6.0,
              ),
            ),
          );
        }

        return PopScope(
          canPop: false,
          onPopInvoked: (didPop) {
            try {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text(
                      textAlign: TextAlign.center,
                      'Close TreeStride?',
                      style: TextStyle(
                        fontSize: 24,
                        color: Colors.black,
                      ),
                    ),
                    actionsAlignment: MainAxisAlignment.spaceAround,
                    actions: <Widget>[
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF08DAD6),
                          surfaceTintColor: const Color(0xFF08DAD6),
                        ),
                        child: const Text(
                          'Stay',
                          style: TextStyle(
                            color: Colors.black,
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF08DAD6),
                          surfaceTintColor: const Color(0xFF08DAD6),
                        ),
                        child: const Text(
                          'Close',
                          style: TextStyle(
                            color: Colors.black,
                          ),
                        ),
                        onPressed: () {
                          SystemNavigator.pop();
                        },
                      ),
                    ],
                  );
                },
              );
            } catch (error) {
              _showErrorToast("Closing Error: $error");
            }
          },
          child: Scaffold(
            backgroundColor: const Color(0xFFEFEFEF),
            appBar: AppBar(
              elevation: 2.0,
              backgroundColor: const Color(0xFFFEFEFE),
              shadowColor: Colors.grey.withOpacity(0.5),
              toolbarHeight: 64,
              centerTitle: true,
              title: Row(
                children: [
                  GestureDetector(
                    onTap: () => _showUserProfile(userDataProvider),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.black12,
                      child: CircleAvatar(
                        radius: 22,
                        backgroundImage: CachedNetworkImageProvider(
                          userDataProvider.userData!['photoURL'],
                        ),
                        onBackgroundImageError: (error, stackTrace) =>
                            const Icon(
                          Icons.image,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userDataProvider.userData!['username'],
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          "Fitness Mode",
                          style: TextStyle(
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                Stack(
                  children: [
                    IconButton(
                      onPressed: () => _navigateToAnnouncements(),
                      icon: const Icon(Icons.notifications_active_outlined),
                    ),
                    if (userDataProvider.unreadAnnouncements != '0')
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            userDataProvider.unreadAnnouncements,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 200,
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
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            NumberFormat("#,###").format(_totalSteps),
                            style: const TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF08DAD6),
                            ),
                          ),
                          const Text(
                            'TOTAL STEPS',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
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
                        children: [
                          const Text(
                            "CHOOSE EXERCISE",
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const WalkingCounterFitness(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF08DAD6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                children: [
                                  Image.asset(
                                    "assets/images/walking.png",
                                    height: 48,
                                    width: 48,
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    "WALKING",
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const JoggingCounterFitness(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF08DAD6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                children: [
                                  Image.asset(
                                    "assets/images/jogging.png",
                                    height: 48,
                                    width: 48,
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    "JOGGING",
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const RunningCounterFitness(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF08DAD6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                children: [
                                  Image.asset(
                                    "assets/images/running.png",
                                    height: 48,
                                    width: 48,
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    "RUNNING",
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                  ),
                                ],
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
          ),
        );
      },
    );
  }
}
