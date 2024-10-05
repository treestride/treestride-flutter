import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'fitness.dart';
import 'home.dart';

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
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const Fitness(),
          ),
        );
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFEFEFEF),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          centerTitle: true,
          title: const Text(
            'CHOOSE MOE',
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
                GestureDetector(
                  onTap: () => {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const Fitness(),
                      ),
                    ),
                  },
                  child: Image.asset("images/planting.png"),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () => {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const Home(),
                      ),
                    ),
                  },
                  child: Image.asset("images/planting.png"),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
