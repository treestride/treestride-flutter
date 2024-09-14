// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:async';
import 'fitness.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WalkingCounterFitness());
}

class WalkingCounterFitness extends StatelessWidget {
  const WalkingCounterFitness({super.key});

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
      home: const WalkingCounterHomeFitness(),
    );
  }
}

class WalkingCounterHomeFitness extends StatefulWidget {
  const WalkingCounterHomeFitness({super.key});

  @override
  WalkingCounterHomeStateFitness createState() =>
      WalkingCounterHomeStateFitness();
}

class WalkingCounterHomeStateFitness extends State<WalkingCounterHomeFitness>
    with WidgetsBindingObserver {
  int _walkingSteps = 0;
  final double _threshold = 12.0;
  List<double> _accelerometerValues = [0, 0, 0];
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  bool _isCountingSteps = false;
  DateTime? _lastStepTime;
  bool _isRunning = false;
  int _walkingGoalSteps = 100;
  DateTime _walkingGoalEndDate = DateTime.now().add(const Duration(days: 7));
  final List<int> _goalOptions = [100, 2000, 5000, 10000];
  bool _isWalkingGoalActive = false;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  void _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _walkingSteps = prefs.getInt('walkingSteps') ?? 0;
      _walkingGoalSteps = prefs.getInt('walkingGoalSteps') ?? 100;
      _walkingGoalEndDate = DateTime.parse(
          prefs.getString('walkingGoalEndDate') ??
              DateTime.now().add(const Duration(days: 7)).toIso8601String());
      _isWalkingGoalActive = prefs.getBool('isWalkingGoalActive') ?? false;
    });
  }

  void _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('walkingSteps', _walkingSteps);
    await prefs.setInt('walkingGoalSteps', _walkingGoalSteps);
    await prefs.setString(
        'walkingGoalEndDate', _walkingGoalEndDate.toIso8601String());
    await prefs.setBool('isWalkingGoalActive', _isWalkingGoalActive);
  }

  void _startStopCounter() {
    setState(() {
      _isRunning = !_isRunning;
      if (_isRunning) {
        _startListening();
      } else {
        _accelerometerSubscription?.cancel();
      }
    });
  }

  void _startListening() {
    _accelerometerSubscription =
        accelerometerEvents.listen((AccelerometerEvent event) {
      setState(() {
        _accelerometerValues = [event.x, event.y, event.z];
        _detectStep();
      });
    });
  }

  void _detectStep() {
    double magnitude = _calculateMagnitude(_accelerometerValues);
    if (!_isCountingSteps && magnitude > _threshold) {
      _isCountingSteps = true;
      _countStep();
    } else if (_isCountingSteps && magnitude < _threshold) {
      _isCountingSteps = false;
    }
  }

  void _countStep() {
    final now = DateTime.now();
    if (_lastStepTime == null ||
        now.difference(_lastStepTime!) > const Duration(milliseconds: 300)) {
      setState(() {
        _walkingSteps++;
        _saveData();
        _checkGoalCompletion();
      });
      _lastStepTime = now;
    }
  }

  void _checkGoalCompletion() {
    if (_isWalkingGoalActive && _walkingSteps >= _walkingGoalSteps ||
        DateTime.now().isBefore(_walkingGoalEndDate)) {
      _showGoalCompletionDialog();
    }
  }

  void _showGoalCompletionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Goal Completed!"),
          content:
              const Text("Congratulations! You've reached your step goal."),
          actions: <Widget>[
            TextButton(
              child: const Text("OK"),
              onPressed: () {
                setState(() {
                  _isWalkingGoalActive = false;
                  _saveData();
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showSetGoalDialog() {
    int tempGoalSteps = _walkingGoalSteps;
    DateTime tempEndDate = _walkingGoalEndDate;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text("Set New Goal"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  DropdownButton<int>(
                    value: tempGoalSteps,
                    items: _goalOptions.map((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text(value.toString()),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setDialogState(() {
                        tempGoalSteps = newValue!;
                      });
                    },
                  ),
                  ElevatedButton(
                    child: Text(tempEndDate.toString().split(' ')[0]),
                    onPressed: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: tempEndDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null && picked != tempEndDate) {
                        setDialogState(() {
                          tempEndDate = picked;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text("Cancel"),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: const Text("Set Goal"),
                  onPressed: () {
                    setState(() {
                      _walkingGoalSteps = tempGoalSteps;
                      _walkingGoalEndDate = tempEndDate;
                      _isWalkingGoalActive = true;
                      _walkingSteps = 0; // Reset steps for new goal
                      _saveData();
                    });
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  double _calculateMagnitude(List<double> accelerometerValues) {
    return accelerometerValues.map((v) => v * v).reduce((a, b) => a + b);
  }

  @override
  void dispose() {
    _accelerometerSubscription?.cancel();
    super.dispose();
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
              'WALKING',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  '$_walkingSteps',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'STEPS TAKEN',
                  style: TextStyle(fontSize: 24),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _startStopCounter,
                  child: Text(_isRunning ? 'Stop' : 'Start'),
                ),
                const SizedBox(height: 20),
                if (_isWalkingGoalActive) ...[
                  Text('Goal: $_walkingGoalSteps steps'),
                  Text(
                    'End Date: ${_walkingGoalEndDate.toString().split(' ')[0]}',
                  ),
                  Text(
                    'Progress: ${(_walkingSteps / _walkingGoalSteps * 100).toStringAsFixed(1)}%',
                  ),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isWalkingGoalActive ? null : _showSetGoalDialog,
                  child: const Text('Set New Goal'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
