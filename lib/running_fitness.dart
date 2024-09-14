// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:async';
import 'fitness.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RunningCounterFitness());
}

class RunningCounterFitness extends StatelessWidget {
  const RunningCounterFitness({super.key});

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
      home: const RunningCounterHomeFitness(),
    );
  }
}

class RunningCounterHomeFitness extends StatefulWidget {
  const RunningCounterHomeFitness({super.key});

  @override
  RunningCounterHomeStateFitness createState() =>
      RunningCounterHomeStateFitness();
}

class RunningCounterHomeStateFitness extends State<RunningCounterHomeFitness>
    with WidgetsBindingObserver {
  int _runningSteps = 0;
  final double _threshold = 12.0;
  List<double> _accelerometerValues = [0, 0, 0];
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  bool _isCountingSteps = false;
  DateTime? _lastStepTime;
  bool _isRunning = false;
  int _runningGoalSteps = 100;
  DateTime _runningGoalEndDate = DateTime.now().add(const Duration(days: 7));
  final List<int> _goalOptions = [100, 2000, 5000, 10000];
  bool _isRunningGoalActive = false;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  void _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _runningSteps = prefs.getInt('runningSteps') ?? 0;
      _runningGoalSteps = prefs.getInt('runningGoalSteps') ?? 100;
      _runningGoalEndDate = DateTime.parse(
          prefs.getString('runningGoalEndDate') ??
              DateTime.now().add(const Duration(days: 7)).toIso8601String());
      _isRunningGoalActive = prefs.getBool('isRunningGoalActive') ?? false;
    });
  }

  void _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('runningSteps', _runningSteps);
    await prefs.setInt('runningGoalSteps', _runningGoalSteps);
    await prefs.setString(
        'runningGoalEndDate', _runningGoalEndDate.toIso8601String());
    await prefs.setBool('isRunningGoalActive', _isRunningGoalActive);
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
        _runningSteps++;
        _saveData();
        _checkGoalCompletion();
      });
      _lastStepTime = now;
    }
  }

  void _checkGoalCompletion() {
    if (_isRunningGoalActive && _runningSteps >= _runningGoalSteps ||
        DateTime.now().isBefore(_runningGoalEndDate)) {
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
                  _isRunningGoalActive = false;
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
    int tempGoalSteps = _runningGoalSteps;
    DateTime tempEndDate = _runningGoalEndDate;

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
                      _runningGoalSteps = tempGoalSteps;
                      _runningGoalEndDate = tempEndDate;
                      _isRunningGoalActive = true;
                      _runningSteps = 0; // Reset steps for new goal
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
              'RUNNING',
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
                  '$_runningSteps',
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
                if (_isRunningGoalActive) ...[
                  Text('Goal: $_runningGoalSteps steps'),
                  Text(
                    'End Date: ${_runningGoalEndDate.toString().split(' ')[0]}',
                  ),
                  Text(
                    'Progress: ${(_runningSteps / _runningGoalSteps * 100).toStringAsFixed(1)}%',
                  ),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isRunningGoalActive ? null : _showSetGoalDialog,
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
