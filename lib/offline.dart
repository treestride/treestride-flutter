// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'splash.dart';

class Offline extends StatelessWidget {
  const Offline({super.key});

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
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.wifi_off,
                size: 100,
                color: Colors.grey,
              ),
              const SizedBox(height: 14),
              const Text(
                'NO INTERNET CONNECTION',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              Column(
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      backgroundColor: const Color(0xFF08DAD6),
                    ),
                    onPressed: () async {
                      var connectivityResult =
                          await Connectivity().checkConnectivity();
                      if (!connectivityResult
                          .contains(ConnectivityResult.none)) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const Splash()),
                        );
                      }
                    },
                    child: const Text(
                      'RETRY',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
