import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'balance_workout.dart';
import 'bmi_calculator.dart';
import 'endurance_workout.dart';
import 'flexibility_workout.dart';
import 'strength_workout.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Workout());
}

class Workout extends StatelessWidget {
  const Workout({super.key});

  @override
  Widget build(BuildContext context) {
    return const WorkoutHome();
  }
}

class WorkoutHome extends StatefulWidget {
  const WorkoutHome({super.key});

  @override
  State<WorkoutHome> createState() => _WorkoutState();
}

class _WorkoutState extends State<WorkoutHome> {
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
          centerTitle: true,
          title: const Text(
            'WORKOUT',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BMI(),
                  ),
                );
              },
              icon: const Icon(
                Icons.assessment,
              ),
              iconSize: 24,
            )
          ],
        ),
        body: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const StrengthWorkoutPlan(),
                        ),
                      ),
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.5),
                                blurRadius: 2,
                                blurStyle: BlurStyle.outer,
                              )
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.asset(
                              fit: BoxFit.cover,
                              "assets/images/strength.jpg",
                              width: double.infinity,
                              height: 200,
                            ),
                          ),
                        ),
                        const Text(
                          "STRENGTH",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () => {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EnduranceWorkoutPlan(),
                        ),
                      ),
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.5),
                            blurRadius: 2,
                            blurStyle: BlurStyle.outer,
                          )
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.asset(
                              fit: BoxFit.cover,
                              "assets/images/endurance.jpg",
                              width: double.infinity,
                              height: 200,
                            ),
                          ),
                          const Text(
                            "ENDURANCE",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () => {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FlexibilityWorkoutPlan(),
                        ),
                      ),
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.5),
                                blurRadius: 2,
                                blurStyle: BlurStyle.outer,
                              )
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.asset(
                              fit: BoxFit.cover,
                              "assets/images/flexibility.jpg",
                              width: double.infinity,
                              height: 200,
                            ),
                          ),
                        ),
                        const Text(
                          "FLEXIBILITY",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () => {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BalanceWorkoutPlan(),
                        ),
                      ),
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.5),
                                blurRadius: 2,
                                blurStyle: BlurStyle.outer,
                              )
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.asset(
                              fit: BoxFit.cover,
                              "assets/images/balance.jpg",
                              width: double.infinity,
                              height: 200,
                            ),
                          ),
                        ),
                        const Text(
                          "BALANCE",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
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
  }
}
