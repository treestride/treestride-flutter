// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_mail_app/open_mail_app.dart';
import 'choose_mode.dart';
import 'offline.dart';

class EmailVerificationPage extends StatefulWidget {
  final User user;

  const EmailVerificationPage({super.key, required this.user});

  @override
  EmailVerificationPageState createState() => EmailVerificationPageState();
}

class EmailVerificationPageState extends State<EmailVerificationPage>
    with WidgetsBindingObserver {
  late Stream<List<ConnectivityResult>> _connectivityStream;
  bool _isEmailVerified = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connectivityStream = Connectivity().onConnectivityChanged;
    _checkConnection();
    _checkEmailVerified();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkEmailVerified();
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

  Future<void> _checkEmailVerified() async {
    await FirebaseAuth.instance.currentUser?.reload();
    setState(() {
      _isEmailVerified =
          FirebaseAuth.instance.currentUser?.emailVerified ?? false;
    });

    if (_isEmailVerified) {
      _timer?.cancel();
      Fluttertoast.showToast(
        msg: "Email Verified!",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.black,
        textColor: Colors.white,
      );
      Future.delayed(Duration.zero, () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ChooseMode()),
        );
      });
    } else {
      _timer ??= Timer.periodic(
        const Duration(seconds: 5),
        (_) => _checkEmailVerified(),
      );
    }
  }

  Future<void> _launchEmailApp() async {
    var result = await OpenMailApp.openMailApp();

    if (!result.didOpen && result.canOpen) {
      showDialog(
        context: context,
        builder: (_) => MailAppPickerDialog(mailApps: result.options),
      );
    } else if (!result.didOpen) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No mail app found on this device"),
        ),
      );
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
          SystemNavigator.pop();
        },
        child: Scaffold(
          appBar: AppBar(
            elevation: 2.0,
            backgroundColor: const Color(0xFFFEFEFE),
            shadowColor: Colors.grey.withOpacity(0.5),
            centerTitle: true,
            title: const Text(
              'EMAIL VERIFICATION',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.email,
                  size: 100,
                  color: Color(0xFF08DAD6),
                ),
                const SizedBox(height: 24),
                const Text(
                  'VERIFY YOUR EMAIL',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32.0),
                  child: Text(
                    'Please check your email inbox and click on the verification link to verify your email address.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _launchEmailApp,
                  icon: const Icon(Icons.email),
                  label: const Text('OPEN EMAIL'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF08DAD6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
