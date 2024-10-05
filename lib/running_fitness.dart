// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:async';
import 'dart:math';
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
  bool _isCounting = false;
  final double _sensitivity = 6;
  double _lastMagnitude = 0;
  int _runningSteps = 0;
  int _totalSteps = 0;
  int _totalRunningSteps = 0;
  DateTime? _selectedDate;
  DateTime _currentDate = DateTime.now();
  DateTime _lastStepTime = DateTime.now();
  StreamSubscription<UserAccelerometerEvent>? _accelerometerSubscription;
  late SharedPreferences _prefs;
  bool _isRunningGoalActive = false;
  String _runningGoal = '0';
  String _runningGoalEndDate = '';

  @override
  void initState() {
    super.initState();
    _initializeData();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopCounting();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      _saveDataToLocalStorage();
    }
  }

  Future<void> _initializeData() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _loadDataFromLocalStorage();
      await _checkGoalCompletion();
      setState(() {
        _currentDate = DateTime.now();
      });
    } catch (error) {
      _showErrorToast("Initialization error: $error");
    }
  }

  void _loadDataFromLocalStorage() {
    setState(() {
      _runningSteps = _prefs.getInt('runningSteps') ?? 0;
      _totalSteps = _prefs.getInt('totalSteps') ?? 0;
      _totalRunningSteps = _prefs.getInt('totalRunningSteps') ?? 0;
      _isRunningGoalActive = _prefs.getBool('isRunningGoalActive') ?? false;
      _runningGoal = _prefs.getString('runningGoal') ?? '0';
      _runningGoalEndDate = _prefs.getString('runningGoalEndDate') ?? '';
    });
  }

  Future<void> _saveDataToLocalStorage() async {
    await _prefs.setInt('runningSteps', _runningSteps);
    await _prefs.setBool('isRunningGoalActive', _isRunningGoalActive);
    await _prefs.setString('runningGoal', _runningGoal);
    await _prefs.setString('runningGoalEndDate', _runningGoalEndDate);
    await _prefs.setInt('totalSteps', _totalSteps);
    await _prefs.setInt('totalRunningSteps', _totalRunningSteps);
  }

  void _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF08DAD6),
              onPrimary: Colors.black,
              surface: Color(0xFFFEFEFE),
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: const Color(0xFFFEFEFE),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.black,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _runningGoalEndDate = DateFormat('yyyy-MM-dd').format(picked);
      });
      _saveDataToLocalStorage();
    }
  }

  void _toggleCounting() {
    if (!_isRunningGoalActive) {
      _showToast("Please start a goal first!");
      return;
    }

    setState(() {
      _isCounting = !_isCounting;
      if (_isCounting) {
        _startCounting();
      } else {
        _stopCounting();
      }
    });
  }

  void _startCounting() {
    _accelerometerSubscription = userAccelerometerEvents.listen(_countSteps);
  }

  void _stopCounting() {
    _accelerometerSubscription?.cancel();
    _saveDataToLocalStorage();
  }

  void _countSteps(UserAccelerometerEvent event) {
    double magnitude =
        sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    DateTime currentTime = DateTime.now();
    Duration timeDiff = currentTime.difference(_lastStepTime);

    if (magnitude > _sensitivity &&
        timeDiff.inMilliseconds > 300 &&
        magnitude - _lastMagnitude > 1.4) {
      setState(() {
        _runningSteps++;
        _totalSteps++;
        _totalRunningSteps++;
      });
      _updateRunningSteps(_runningSteps, _totalSteps, _totalRunningSteps);
      _lastStepTime = currentTime;

      // Check goal completion after each step
      _checkGoalCompletion().then((_) {
        if (!_isRunningGoalActive) {
          _stopCounting();
          setState(() {
            _isCounting = false;
          });
        }
      });
    }
    _lastMagnitude = magnitude;
  }

  Future<void> _updateRunningSteps(
      int newStepCount, int totalStepCount, int totalRunningSteps) async {
    await _prefs.setInt('runningSteps', newStepCount);
    await _prefs.setInt('totalSteps', totalStepCount);
    await _prefs.setInt('totalRunningSteps', totalRunningSteps);
  }

  Future<void> _checkGoalCompletion() async {
    if (_isRunningGoalActive) {
      int currentSteps = _runningSteps;
      int goalSteps = int.parse(_runningGoal);
      DateTime endDate = DateTime.parse(_runningGoalEndDate);

      if (currentSteps >= goalSteps || DateTime.now().isAfter(endDate)) {
        setState(() {
          _isRunningGoalActive = false;
          _runningSteps = 0;
          _runningGoal = '0';
          _runningGoalEndDate = '';
        });
        _saveDataToLocalStorage();
        _showToast("Congratulations! You've completed your running goal!");
      }
    }
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

  void _showErrorToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: const Color(0xFFB43838),
      textColor: Colors.white,
    );
  }

  final InputDecoration _dropdownDecoration = InputDecoration(
    contentPadding:
        const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14.0),
      borderSide: const BorderSide(
        color: Color(0xFF08DAD6),
        width: 2,
      ),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14.0),
      borderSide: const BorderSide(
        color: Colors.grey,
        width: 2,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14.0),
      borderSide: const BorderSide(
        color: Color(0xFF08DAD6),
        width: 2,
      ),
    ),
    filled: true,
    fillColor: Colors.white,
  );

  @override
  Widget build(BuildContext context) {
    bool isEndDateValid = _runningGoalEndDate.isNotEmpty &&
        DateTime.parse(_runningGoalEndDate).isAfter(_currentDate);
    bool isGoalSelectionValid = _runningGoal != '0';

    // Calculate progress
    double progress = _isRunningGoalActive
        ? (_runningSteps / int.parse(_runningGoal)).clamp(0.0, 1.0)
        : 0.0;

    // Check if user is close to goal
    bool isCloseToGoal = _isRunningGoalActive && progress >= 0.7;

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
          _stopCounting();
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
                _stopCounting();
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
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: double.infinity,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.only(
                            top: 24,
                            left: 24,
                            bottom: 32,
                            right: 24,
                          ),
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
                                NumberFormat("#,###").format(_runningSteps),
                                style: const TextStyle(
                                  fontSize: 64,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                'STEPS',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                onPressed: _toggleCounting,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF08DAD6),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                    horizontal: 24,
                                  ),
                                ),
                                child: Text(
                                  _isCounting ? 'STOP' : 'START',
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Image.asset(
                          "assets/images/running.png",
                          height: 48,
                          width: 48,
                        ),
                        const SizedBox(height: 14),
                        if (_isRunningGoalActive) ...[
                          SizedBox(
                            width: 200,
                            child: LinearProgressIndicator(
                              borderRadius: BorderRadius.circular(14),
                              value: progress,
                              backgroundColor: Colors.grey[300],
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF08DAD6),
                              ),
                              minHeight: 10,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            textAlign: TextAlign.center,
                            '${(progress * 100).toStringAsFixed(1)}% Complete',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF08DAD6),
                            ),
                          ),
                          if (isCloseToGoal)
                            const Padding(
                              padding: EdgeInsets.only(top: 10),
                              child: Text(
                                textAlign: TextAlign.center,
                                'Almost there! Keep going!',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                        const SizedBox(height: 14),
                        Text(
                          "${NumberFormat('#,###').format(int.parse(_runningGoal))} STEP${int.parse(_runningGoal) == 0 || int.parse(_runningGoal) == 1 ? '' : 'S'}",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'STEP GOAL',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Center(
                          child: SizedBox(
                            width: 250,
                            child: DropdownButtonFormField<String>(
                              value: _runningGoal == '0' ? null : _runningGoal,
                              onChanged: _isRunningGoalActive
                                  ? null
                                  : (String? newValue) {
                                      if (newValue != null) {
                                        setState(() {
                                          _runningGoal = newValue;
                                        });
                                        _saveDataToLocalStorage();
                                      }
                                    },
                              items: [
                                "100",
                                "3000",
                                "5000",
                                "10000",
                                "20000"
                              ].map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(
                                      "${NumberFormat('#,###').format(int.parse(value))} STEPS"),
                                );
                              }).toList(),
                              decoration: _dropdownDecoration.copyWith(
                                enabled: !_isRunningGoalActive,
                              ),
                              hint: const Text("0 STEP"),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Center(
                          child: SizedBox(
                            width: 250,
                            child: ElevatedButton(
                              onPressed: _isRunningGoalActive
                                  ? null
                                  : () => _selectDate(context),
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                backgroundColor: const Color(0xFF08DAD6),
                                disabledBackgroundColor: Colors.grey,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 14,
                                ),
                              ),
                              child: Text(
                                _runningGoalEndDate.isNotEmpty &&
                                        DateTime.parse(_runningGoalEndDate)
                                            .isAfter(_currentDate)
                                    ? 'END DATE: ${DateFormat('MMMM d, yyyy').format(DateTime.parse(_runningGoalEndDate)).toUpperCase()}'
                                    : 'PICK DATE: ${DateFormat('MMMM d, yyyy').format(_currentDate).toUpperCase()}',
                                style: TextStyle(
                                  color: _isRunningGoalActive
                                      ? Colors.white
                                      : Colors.black,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: _isRunningGoalActive
                                  ? null
                                  : () {
                                      if (isGoalSelectionValid &&
                                          !_isRunningGoalActive &&
                                          isEndDateValid) {
                                        _setGoal();
                                      } else {
                                        _showToast(
                                            "Please change the default values!");
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                backgroundColor: const Color(0xFF08DAD6),
                                disabledBackgroundColor: Colors.grey,
                              ),
                              child: Text(
                                _isRunningGoalActive
                                    ? 'IN PROGRESS'
                                    : 'START GOAL',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _isRunningGoalActive
                                      ? Colors.white
                                      : Colors.black,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            ElevatedButton(
                              onPressed: _isRunningGoalActive
                                  ? () => _showResetConfirmationDialog(context)
                                  : null,
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                backgroundColor: const Color(0xFFB43838),
                                disabledBackgroundColor: Colors.grey,
                              ),
                              child: const Icon(
                                Icons.restart_alt,
                                color: Colors.white,
                              ),
                            ),
                          ],
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

  void _showResetConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          actionsAlignment: MainAxisAlignment.spaceAround,
          title: const Text(
            textAlign: TextAlign.center,
            'RESET GOAL',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            textAlign: TextAlign.center,
            'Are you sure you want to reset your goal? Note that this action cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF08DAD6),
                surfaceTintColor: const Color(0xFF08DAD6),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.black,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text(
                'Reset',
                style: TextStyle(
                  color: Colors.black,
                ),
              ),
              onPressed: () {
                _resetGoal();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _setGoal() {
    setState(() {
      _isRunningGoalActive = true;
      _runningSteps = 0;
    });
    _saveDataToLocalStorage();
    _showToast("Goal started!");
  }

  void _resetGoal() {
    setState(() {
      _isRunningGoalActive = false;
      _runningSteps = 0;
      _runningGoal = '0';
      _runningGoalEndDate = '';
    });
    _saveDataToLocalStorage();
    _showToast("Goal Reset!");
  }
}
