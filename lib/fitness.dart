import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'login.dart';
import 'user_data_provider.dart';

class FitnessMode extends StatefulWidget {
  const FitnessMode({super.key});

  @override
  State<FitnessMode> createState() => FitnessState();
}

class FitnessState extends State<FitnessMode> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    final provider = Provider.of<UserDataProvider>(context, listen: false);
    try {
      await provider.fetchUserData();
    } catch (error) {
      _showErrorToast("Initialization error: $error");
      Future.delayed(Duration.zero, () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const Login()),
        );
      });
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
                  backgroundColor: const Color(0xFF08DAD6),
                  child: CircleAvatar(
                    radius: 62,
                    backgroundImage: NetworkImage(
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
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FitnessMode(),
                      ),
                    );
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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => _showUserProfile(userDataProvider),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFF08DAD6),
                      child: CircleAvatar(
                        radius: 22,
                        backgroundImage: NetworkImage(
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
                        const SizedBox(height: 6),
                        Text(
                          textAlign: TextAlign.center,
                          "TOTAL STEPS: ${NumberFormat('#,###').format(int.parse('1'))}",
                          style: const TextStyle(
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Column(
                          children: [
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
                                  Text(
                                    NumberFormat('#,###').format(
                                      int.parse('1'),
                                    ),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text("Total Walking Steps"),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
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
                                  Text(
                                    NumberFormat('#,###').format(
                                      int.parse('1'),
                                    ),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text("Total Jogging Steps"),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
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
                                  Text(
                                    NumberFormat('#,###').format(
                                      int.parse('1'),
                                    ),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text("Total Running Steps"),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            ElevatedButton(
                              onPressed: () {},
                              child: Text("BUTTON"),
                            ),
                            ElevatedButton(
                              onPressed: () {},
                              child: Text("BUTTON"),
                            ),
                          ],
                        )
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}
