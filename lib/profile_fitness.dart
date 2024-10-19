import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'workout.dart';
import 'fitness.dart';
import 'user_data_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProfileFitness());
}

class ProfileFitness extends StatelessWidget {
  const ProfileFitness({super.key});

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
      home: const ProfileFitnessHome(),
    );
  }
}

class ProfileFitnessHome extends StatefulWidget {
  const ProfileFitnessHome({super.key});

  @override
  ProfileFitnessHomeState createState() => ProfileFitnessHomeState();
}

class ProfileFitnessHomeState extends State<ProfileFitnessHome>
    with WidgetsBindingObserver {
  int _totalWalkingSteps = 0;
  int _totalJoggingSteps = 0;
  int _totalRunningSteps = 0;

  @override
  void initState() {
    super.initState();
    _loadTotalWalkingSteps();
  }

  Future<void> _loadTotalWalkingSteps() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _totalWalkingSteps = prefs.getInt('totalWalkingSteps') ?? 0;
      _totalJoggingSteps = prefs.getInt('totalJoggingSteps') ?? 0;
      _totalRunningSteps = prefs.getInt('totalRunningSteps') ?? 0;
    });
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
          onPopInvoked: (didPop) async {
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
                'PROFILE',
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
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const Workout(),
                        ),
                      );
                    },
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
                    onTap: () {},
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
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 32),
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
                            CircleAvatar(
                              radius: 64,
                              backgroundColor: Colors.black12,
                              child: CircleAvatar(
                                radius: 62,
                                backgroundImage: NetworkImage(
                                  userDataProvider.userData!['photoURL'] ??
                                      'N/A',
                                ),
                                onBackgroundImageError: (error, stacktrace) =>
                                    const Icon(
                                  Icons.image,
                                  size: 64,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              userDataProvider.userData!['username'],
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              userDataProvider.userData!['email'],
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              userDataProvider.userData!['phoneNumber'],
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
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
                              NumberFormat("#,###").format(_totalWalkingSteps),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF08DAD6),
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              "TOTAL WALKING STEPS",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
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
                              NumberFormat("#,###").format(_totalJoggingSteps),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF08DAD6),
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              "TOTAL JOGGING STEPS",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
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
                              NumberFormat("#,###").format(_totalRunningSteps),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF08DAD6),
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              "TOTAL RUNNING STEPS",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
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
          ),
        );
      },
    );
  }
}
