// ignore_for_file: deprecated_member_use

import 'dart:convert';

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
  bool _isCounting = false;
  final double _sensitivity = 6;
  double _lastMagnitude = 0;
  int _dailyWalkingSteps = 0;
  int _walkingSteps = 0;
  int _totalSteps = 0;
  int _totalWalkingSteps = 0;
  DateTime? _selectedDate;
  DateTime _currentDate = DateTime.now();
  DateTime _lastStepTime = DateTime.now();
  StreamSubscription<UserAccelerometerEvent>? _accelerometerSubscription;
  late SharedPreferences _prefs;
  bool _isWalkingGoalActive = false;
  String _walkingGoal = '0';
  String _walkingGoalEndDate = '';
  Map<String, int> _walkingStepHistory = {};

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
      _checkAndResetDailySteps();
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
      _walkingSteps = _prefs.getInt('walkingSteps') ?? 0;
      _totalSteps = _prefs.getInt('totalSteps') ?? 0;
      _totalWalkingSteps = _prefs.getInt('totalWalkingSteps') ?? 0;
      _isWalkingGoalActive = _prefs.getBool('isWalkingGoalActive') ?? false;
      _walkingGoal = _prefs.getString('walkingGoal') ?? '0';
      _walkingGoalEndDate = _prefs.getString('walkingGoalEndDate') ?? '';
      String? walkingStepHistoryJson = _prefs.getString('walkingStepHistory');
      if (walkingStepHistoryJson != null) {
        Map<String, dynamic> decodedMap = json.decode(walkingStepHistoryJson);
        _walkingStepHistory =
            decodedMap.map((key, value) => MapEntry(key, value as int));
      } else {
        _walkingStepHistory = {};
      }
    });
  }

  Future<void> _saveDataToLocalStorage() async {
    await _prefs.setInt('walkingSteps', _walkingSteps);
    await _prefs.setBool('isWalkingGoalActive', _isWalkingGoalActive);
    await _prefs.setString('walkingGoal', _walkingGoal);
    await _prefs.setString('walkingGoalEndDate', _walkingGoalEndDate);
    await _prefs.setInt('totalSteps', _totalSteps);
    await _prefs.setInt('totalWalkingSteps', _totalWalkingSteps);
    await _prefs.setInt('dailyWalkingSteps', _dailyWalkingSteps);
    await _prefs.setString(
        'walkingStepHistory', json.encode(_walkingStepHistory));
    await _prefs.setString('lastWalkingRecordedDay',
        DateFormat('yyyy-MM-dd').format(DateTime.now()));
  }

  void _updateStepHistory() {
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _walkingStepHistory[today] = (_walkingStepHistory[today] ?? 0) + 1;
    _saveDataToLocalStorage();
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
        _walkingGoalEndDate = DateFormat('yyyy-MM-dd').format(picked);
      });
      _saveDataToLocalStorage();
    }
  }

  void _toggleCounting() {
    if (!_isWalkingGoalActive) {
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
    _checkAndResetDailySteps();

    double magnitude =
        sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    DateTime currentTime = DateTime.now();
    Duration timeDiff = currentTime.difference(_lastStepTime);

    if (magnitude > _sensitivity &&
        timeDiff.inMilliseconds > 300 &&
        magnitude - _lastMagnitude > 1.4) {
      setState(() {
        _dailyWalkingSteps++;
        _walkingSteps++;
        _totalSteps++;
        _totalWalkingSteps++;
        _updateStepHistory();
        _updateWalkingSteps(
          _walkingSteps,
          _totalSteps,
          _totalWalkingSteps,
          _dailyWalkingSteps,
        );
      });
      _lastStepTime = currentTime;

      // Check goal completion after each step
      _checkGoalCompletion().then((_) {
        if (!_isWalkingGoalActive) {
          _stopCounting();
          setState(() {
            _isCounting = false;
          });
        }
      });
    }
    _lastMagnitude = magnitude;
  }

  Future<void> _updateWalkingSteps(int newStepCount, int totalStepCount,
      int totalWalkingSteps, int dailyWalkingSteps) async {
    await _prefs.setInt('walkingSteps', newStepCount);
    await _prefs.setInt('totalSteps', totalStepCount);
    await _prefs.setInt('dailyWalkingSteps', dailyWalkingSteps);
    await _prefs.setInt('totalWalkingSteps', totalWalkingSteps);
  }

  Future<void> _checkGoalCompletion() async {
    if (_isWalkingGoalActive) {
      int currentSteps = _walkingSteps;
      int goalSteps = int.parse(_walkingGoal);
      DateTime endDate = DateTime.parse(_walkingGoalEndDate);

      if (currentSteps >= goalSteps || DateTime.now().isAfter(endDate)) {
        setState(() {
          _isWalkingGoalActive = false;
          _walkingSteps = 0;
          _walkingGoal = '0';
          _walkingGoalEndDate = '';
        });
        _saveDataToLocalStorage();
        _showToast("Congratulations! You've completed your walking goal!");
      }
    }
  }

  void _checkAndResetDailySteps() {
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    String lastRecordedDay = _prefs.getString('lastWalkingRecordedDay') ?? '';

    if (today != lastRecordedDay) {
      // It's a new day, reset the walking steps
      _dailyWalkingSteps = 0;
      _prefs.setInt('dailyWalkingSteps', 0);
      _prefs.setString('lastWalkingRecordedDay', today);

      // Ensure there's an entry for today in the history
      if (!_walkingStepHistory.containsKey(today)) {
        _walkingStepHistory[today] = 0;
      }

      // Save the updated history
      _saveDataToLocalStorage();
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
    bool isEndDateValid = _walkingGoalEndDate.isNotEmpty &&
        DateTime.parse(_walkingGoalEndDate).isAfter(_currentDate);
    bool isGoalSelectionValid = _walkingGoal != '0';

    // Calculate progress
    double progress = _isWalkingGoalActive
        ? (_walkingSteps / int.parse(_walkingGoal)).clamp(0.0, 1.0)
        : 0.0;

    // Check if user is close to goal
    bool isCloseToGoal = _isWalkingGoalActive && progress >= 0.7;

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
              'WALKING',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              IconButton(
                onPressed: () => {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StepHistoryPage(
                          walkingStepHistory: _walkingStepHistory),
                    ),
                  ),
                },
                icon: const Icon(Icons.history),
              ),
            ],
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
                                NumberFormat("#,###").format(_walkingSteps),
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
                          "assets/images/walking.png",
                          height: 48,
                          width: 48,
                        ),
                        const SizedBox(height: 14),
                        if (_isWalkingGoalActive) ...[
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
                          "${NumberFormat('#,###').format(int.parse(_walkingGoal))} STEP${int.parse(_walkingGoal) == 0 || int.parse(_walkingGoal) == 1 ? '' : 'S'}",
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
                              value: _walkingGoal == '0' ? null : _walkingGoal,
                              onChanged: _isWalkingGoalActive
                                  ? null
                                  : (String? newValue) {
                                      if (newValue != null) {
                                        setState(() {
                                          _walkingGoal = newValue;
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
                                enabled: !_isWalkingGoalActive,
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
                              onPressed: _isWalkingGoalActive
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
                                _walkingGoalEndDate.isNotEmpty &&
                                        DateTime.parse(_walkingGoalEndDate)
                                            .isAfter(_currentDate)
                                    ? 'END DATE: ${DateFormat('MMMM d, yyyy').format(DateTime.parse(_walkingGoalEndDate)).toUpperCase()}'
                                    : 'PICK DATE: ${DateFormat('MMMM d, yyyy').format(_currentDate).toUpperCase()}',
                                style: TextStyle(
                                  color: _isWalkingGoalActive
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
                              onPressed: _isWalkingGoalActive
                                  ? null
                                  : () {
                                      if (isGoalSelectionValid &&
                                          !_isWalkingGoalActive &&
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
                                _isWalkingGoalActive
                                    ? 'IN PROGRESS'
                                    : 'START GOAL',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _isWalkingGoalActive
                                      ? Colors.white
                                      : Colors.black,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            ElevatedButton(
                              onPressed: _isWalkingGoalActive
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
      _isWalkingGoalActive = true;
      _walkingSteps = 0;
    });
    _saveDataToLocalStorage();
    _showToast("Goal started!");
  }

  void _resetGoal() {
    setState(() {
      _isWalkingGoalActive = false;
      _walkingSteps = 0;
      _walkingGoal = '0';
      _walkingGoalEndDate = '';
    });
    _saveDataToLocalStorage();
    _showToast("Goal Reset!");
  }
}

class StepHistoryPage extends StatelessWidget {
  final Map<String, int> walkingStepHistory;

  const StepHistoryPage({super.key, required this.walkingStepHistory});

  @override
  Widget build(BuildContext context) {
    List<MapEntry<String, int>> sortedEntries = walkingStepHistory.entries
        .toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return Scaffold(
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
                builder: (context) => const WalkingCounterFitness(),
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
          'WALKING HISTORY',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: sortedEntries.length,
        itemBuilder: (context, index) {
          final entry = sortedEntries[index];
          return Container(
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
            child: ListTile(
              title: Text(
                DateFormat('MMMM d, yyyy').format(
                  DateTime.parse(entry.key),
                ),
              ),
              trailing: Text(
                '${entry.value} steps',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
