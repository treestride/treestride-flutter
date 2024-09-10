// ignore_for_file: unused_field, use_build_context_synchronously, deprecated_member_use

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'dart:async';
import 'dart:math';
import 'home.dart';
import 'offline.dart';
import 'user_data_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const JoggingCounter());
}

class JoggingCounter extends StatelessWidget {
  const JoggingCounter({super.key});

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
      home: const JoggingCounterHome(),
    );
  }
}

class JoggingCounterHome extends StatefulWidget {
  const JoggingCounterHome({super.key});

  @override
  JoggingCounterHomeState createState() => JoggingCounterHomeState();
}

class JoggingCounterHomeState extends State<JoggingCounterHome>
    with WidgetsBindingObserver {
  bool _isCounting = false;
  double _lastMagnitude = 0;
  final double _sensitivity = 6;
  int _joggingSteps = 0;
  DateTime? _selectedDate;
  DateTime _currentDate = DateTime.now();
  DateTime _lastStepTime = DateTime.now();
  StreamSubscription<UserAccelerometerEvent>? _accelerometerSubscription;
  late Stream<List<ConnectivityResult>> _connectivityStream;

  @override
  void initState() {
    super.initState();
    _initializeData();
    WidgetsBinding.instance.addObserver(this);
    _connectivityStream = Connectivity().onConnectivityChanged;
    _checkConnection();
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
      final provider = Provider.of<UserDataProvider>(context, listen: false);
      provider.saveDataToFirestore();
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

  Future<void> _initializeData() async {
    try {
      final provider = Provider.of<UserDataProvider>(context, listen: false);
      await provider.fetchUserData();
      await provider.checkGoalCompletion('jogging');
      setState(() {
        _joggingSteps = int.parse(provider.userData!['joggingSteps']);
        _currentDate = DateTime.now();
      });
    } catch (error) {
      _showErrorToast("Initialization error: $error");
    }
  }

  void _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _currentDate,
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
      });
      final provider = Provider.of<UserDataProvider>(context, listen: false);
      provider.updateUserData({
        'joggingGoalEndDate': DateFormat('yyyy-MM-dd').format(picked),
      });
    }
  }

  void _toggleCounting() {
    final provider = Provider.of<UserDataProvider>(context, listen: false);
    if (provider.userData!['isJoggingGoalActive'] == 'false') {
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
    final provider = Provider.of<UserDataProvider>(context, listen: false);
    provider.saveDataToFirestore();
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
        _joggingSteps++;
      });
      _updateJoggingSteps(_joggingSteps);
      _lastStepTime = currentTime;

      // Check goal completion after each step
      final provider = Provider.of<UserDataProvider>(context, listen: false);
      provider.checkGoalCompletion('jogging').then((_) {
        if (provider.userData!['isJoggingGoalActive'] == 'false') {
          _stopCounting();
          setState(() {
            _isCounting = false;
          });
        }
      });
    }
    _lastMagnitude = magnitude;
  }

  Future<void> _updateJoggingSteps(int newStepCount) async {
    final provider = Provider.of<UserDataProvider>(context, listen: false);
    await provider.updateSteps('jogging', newStepCount);
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
    return MaterialApp(
      theme: ThemeData(
        textTheme: GoogleFonts.exo2TextTheme(
          Theme.of(context).textTheme,
        ),
        primaryTextTheme: GoogleFonts.exoTextTheme(
          Theme.of(context).primaryTextTheme,
        ),
      ),
      home: Consumer<UserDataProvider>(
        builder: (context, userDataProvider, child) {
          bool isJoggingGoalActive =
              userDataProvider.userData!['isJoggingGoalActive'] == 'true';
          String joggingGoal = userDataProvider.userData!['joggingGoal'];
          String joggingGoalEndDateStr =
              userDataProvider.userData!['joggingGoalEndDate'];
          DateTime joggingGoalEndDate = DateTime.parse(joggingGoalEndDateStr);
          bool isEndDateValid = joggingGoalEndDate.isAfter(_currentDate);
          bool isGoalSelectionValid = joggingGoal != '0';
          String currentSteps = userDataProvider.userData!['joggingSteps'];

          // Calculate progress
          double progress = isJoggingGoalActive
              ? (int.parse(currentSteps) / int.parse(joggingGoal))
                  .clamp(0.0, 1.0)
              : 0.0;

          // Check if user is close to goal
          bool isCloseToGoal = isJoggingGoalActive && progress >= 0.7;

          return PopScope(
            canPop: false,
            onPopInvoked: (didPop) async {
              _stopCounting();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const Home(),
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
                        builder: (context) => const Home(),
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
                  'JOGGING',
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
                                    NumberFormat("#,###").format(int.parse(
                                        userDataProvider
                                            .userData!['joggingSteps'])),
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
                              "assets/images/jogging.png",
                              height: 48,
                              width: 48,
                            ),
                            const SizedBox(height: 14),
                            if (isJoggingGoalActive) ...[
                              SizedBox(
                                width: 200,
                                child: LinearProgressIndicator(
                                  borderRadius: BorderRadius.circular(14),
                                  value: progress,
                                  backgroundColor: Colors.grey[300],
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
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
                              "${NumberFormat('#,###').format(int.parse(joggingGoal))} STEP${int.parse(joggingGoal) == 0 || int.parse(joggingGoal) == 1 ? '' : 'S'}",
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
                                  value:
                                      joggingGoal == '0' ? null : joggingGoal,
                                  onChanged: isJoggingGoalActive
                                      ? null
                                      : (String? newValue) {
                                          if (newValue != null) {
                                            userDataProvider.updateUserData({
                                              'joggingGoal': newValue,
                                            });
                                          }
                                        },
                                  items: [
                                    "100",
                                    "3000",
                                    "5000",
                                    "10000",
                                    "20000"
                                  ].map<DropdownMenuItem<String>>(
                                      (String value) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(
                                          "${NumberFormat('#,###').format(int.parse(value))} STEPS"),
                                    );
                                  }).toList(),
                                  decoration: _dropdownDecoration.copyWith(
                                    enabled: !isJoggingGoalActive,
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
                                  onPressed: isJoggingGoalActive
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
                                    joggingGoalEndDate != _currentDate &&
                                            joggingGoalEndDate
                                                .isAfter(_currentDate)
                                        ? 'END DATE: ${DateFormat('MMMM d, yyyy').format(joggingGoalEndDate).toUpperCase()}'
                                        : 'PICK DATE: ${DateFormat('MMMM d, yyyy').format(_currentDate).toUpperCase()}',
                                    style: TextStyle(
                                      color: isJoggingGoalActive
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
                                  onPressed: isJoggingGoalActive
                                      ? null
                                      : () {
                                          if (isGoalSelectionValid &&
                                              !isJoggingGoalActive &&
                                              isEndDateValid) {
                                            userDataProvider.setGoal(
                                              'jogging',
                                              joggingGoal,
                                              joggingGoalEndDate,
                                            );
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
                                    isJoggingGoalActive
                                        ? 'IN PROGRESS'
                                        : 'START GOAL',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isJoggingGoalActive
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                ElevatedButton(
                                  onPressed: isJoggingGoalActive
                                      ? () => _showResetConfirmationDialog(
                                          context, userDataProvider)
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
          );
        },
      ),
    );
  }

  void _showResetConfirmationDialog(
      BuildContext context, UserDataProvider userDataProvider) {
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
                userDataProvider.resetGoal('jogging');
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
