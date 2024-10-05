import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'fitness.dart';
import 'profile_fitness.dart';
import 'assessment_test.dart';
import 'assessment_result.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Assessment());
}

class Assessment extends StatelessWidget {
  const Assessment({super.key});

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
      home: const AssessmentHome(),
    );
  }
}

class AssessmentHome extends StatefulWidget {
  const AssessmentHome({super.key});

  @override
  State<AssessmentHome> createState() => _AssessmentState();
}

class _AssessmentState extends State<AssessmentHome> {
  bool _showTest = true;
  List<String> _testAnswers = [];

  void _completeTest(List<String> answers) {
    setState(() {
      _testAnswers = answers;
      _showTest = false;
    });
  }

  void _restartTest() {
    setState(() {
      _showTest = true;
      _testAnswers = [];
    });
  }

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
          elevation: 2.0,
          backgroundColor: const Color(0xFFFEFEFE),
          shadowColor: Colors.grey.withOpacity(0.5),
          leading: IconButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const Fitness(),
                ),
              );
            },
            icon: const Icon(
              Icons.arrow_back,
            ),
            iconSize: 24,
          ),
          centerTitle: true,
          title: const Text(
            'ASSESSMENT',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          decoration: BoxDecoration(
            color: const Color(0xFFFEFEFE),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                spreadRadius: 1,
                blurRadius: 2,
                offset: const Offset(0, -1),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              GestureDetector(
                onTap: () {},
                child: const Icon(
                  Icons.fitness_center_outlined,
                  size: 30,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const Fitness(),
                    ),
                  );
                },
                child: const Icon(
                  Icons.directions_walk_outlined,
                  size: 30,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileFitness(),
                    ),
                  );
                },
                child: const Icon(
                  Icons.person,
                  size: 30,
                ),
              ),
            ],
          ),
        ),
        body: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  if (_showTest)
                    AssessmentTest(onComplete: _completeTest)
                  else
                    AssessmentResults(
                      answers: _testAnswers,
                      onReassess: _restartTest,
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
