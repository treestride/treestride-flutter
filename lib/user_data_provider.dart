// ignore_for_file: unrelated_type_equality_checks

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

class UserDataProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _dataChanged = false;
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _missionData;
  StreamSubscription<DocumentSnapshot>? _missionListener;
  String _unreadAnnouncements = '0';
  String _unreadPosts = '0';

  Map<String, dynamic>? get userData => _userData;
  Map<String, dynamic>? get missionData => _missionData;
  String get unreadAnnouncements => _unreadAnnouncements;
  String get unreadPosts => _unreadPosts;

  Future<bool> checkInternetConnection() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  Future<void> fetchUserData() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        DocumentSnapshot doc =
            await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          _userData = _extractUserData(doc.data() as Map<String, dynamic>);
        } else {
          _showToast('User data not found!', isError: true);
        }
      } else {
        _showToast('No user logged in!', isError: true);
      }
    } catch (e) {
      _showToast('Failed to load user data: $e', isError: true);
    }
    _dataChanged = true;
    notifyListeners();
  }

  Map<String, dynamic> _extractUserData(Map<String, dynamic> data) {
    return {
      'photoURL': data['photoURL'] ?? 'N/A',
      'username': data['username'] ?? 'N/A',
      'email': data['email'] ?? 'N/A',
      'password': data['password'] ?? 'N/A',
      'phoneNumber': data['phoneNumber'] ?? 'N/A',
      'totalPoints': data['totalPoints']?.toString() ?? '0',
      'totalSteps': data['totalSteps']?.toString() ?? '0',
      'missionSteps': data['missionSteps']?.toString() ?? '0',
      'groupMissionSteps': data['groupMissionSteps']?.toString() ?? '0',
      'walkingSteps': data['walkingSteps']?.toString() ?? '0',
      'walkingGoal': data['walkingGoal']?.toString() ?? '0',
      'walkingGoalEndDate': _formatDate(data['walkingGoalEndDate']),
      'isWalkingGoalActive': data['isWalkingGoalActive']?.toString() ?? 'false',
      'joggingSteps': data['joggingSteps']?.toString() ?? '0',
      'joggingGoal': data['joggingGoal']?.toString() ?? '0',
      'joggingGoalEndDate': _formatDate(data['joggingGoalEndDate']),
      'isJoggingGoalActive': data['isJoggingGoalActive']?.toString() ?? 'false',
      'runningSteps': data['runningSteps']?.toString() ?? '0',
      'runningGoal': data['runningGoal']?.toString() ?? '0',
      'runningGoalEndDate': _formatDate(data['runningGoalEndDate']),
      'isRunningGoalActive': data['isRunningGoalActive']?.toString() ?? 'false',
      'missionsCompleted': data['missionsCompleted']?.toString() ?? '0',
      'totalTrees': data['totalTrees']?.toString() ?? '0',
      'certificates': data['certificates']?.toString() ?? '0',
      'isMissionCompleted': data['isMissionCompleted']?.toString() ?? 'false',
      'lastAnnouncementViewTime': data['lastAnnouncementViewTime'] ??
          Timestamp.fromDate(DateTime(2000)),
      'lastPostViewTime':
          data['lastPostViewTime'] ?? Timestamp.fromDate(DateTime(2000)),
      'fromPangasinan': data['fromPangasinan']?.toString() ?? "false",
    };
  }

  Future<void> initializeMissionData() async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('mission').doc('currentMission').get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        _missionData = {
          'steps': data['steps']?.toString() ?? 'N/A',
          'reward': data['reward']?.toString() ?? 'N/A',
          'endDate': data['endDate']?.toString() ?? 'N/A',
        };
      } else {
        _showToast('Mission data not found', isError: true);
        _missionData = {'steps': 'N/A', 'reward': 'N/A', 'endDate': 'N/A'};
      }
    } catch (e) {
      _showToast('Failed to load mission data: $e', isError: true);
      _missionData = {'steps': 'N/A', 'reward': 'N/A', 'endDate': 'N/A'};
    }
    _dataChanged = true;
    notifyListeners();
  }

  Future<void> fetchMissionData() async {
    await initializeMissionData();
    _missionListener?.cancel();
    _missionListener = _firestore
        .collection('mission')
        .doc('currentMission')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        Map<String, dynamic> newMissionData =
            snapshot.data() as Map<String, dynamic>;
        bool missionChanged = _missionData == null ||
            _missionData!['steps'] != newMissionData['steps']?.toString() ||
            _missionData!['reward'] != newMissionData['reward']?.toString() ||
            _missionData!['endDate'] != newMissionData['endDate']?.toString();

        if (missionChanged) {
          _missionData = {
            'steps': newMissionData['steps']?.toString() ?? 'N/A',
            'reward': newMissionData['reward']?.toString() ?? 'N/A',
            'endDate': newMissionData['endDate']?.toString() ?? 'N/A',
          };
          _resetUserMissionProgress();
          _dataChanged = true;
          notifyListeners();
        }
      }
    });

    // Add a listener for the mission queue
    _firestore.collection('missionQueue').snapshots().listen((snapshot) {
      // Optionally update local queue state
    });
  }

  Future<void> checkMissionStatus() async {
    if (_missionData == null) return;

    DateTime now = DateTime.now();
    DateTime missionEnd = DateTime.parse(_missionData!['endDate']);

    if (now.isAfter(missionEnd)) {
      // Load next mission from queue
      await loadNextMissionFromQueue();
    }
  }

  Future<void> loadNextMissionFromQueue() async {
    QuerySnapshot queueSnapshot = await _firestore
        .collection('missionQueue')
        .orderBy('endDate')
        .limit(1)
        .get();

    if (queueSnapshot.docs.isNotEmpty) {
      DocumentSnapshot nextMissionDoc = queueSnapshot.docs.first;
      Map<String, dynamic> nextMissionData =
          nextMissionDoc.data() as Map<String, dynamic>;

      // Set the next mission as the active mission
      await _firestore
          .collection('mission')
          .doc('currentMission')
          .set(nextMissionData);
      await nextMissionDoc.reference.delete();

      // Fetch the updated mission data
      await fetchMissionData();
    }
  }

  Future<void> _resetUserMissionProgress() async {
    _userData!['missionSteps'] = '0';
    _userData!['isMissionCompleted'] = 'false';
    _dataChanged = true;
    await saveDataToFirestore();
    _showToast("Mission Updated!");
  }

  @override
  void dispose() {
    _missionListener?.cancel();
    super.dispose();
  }

  Future<void> saveDataToFirestore() async {
    if (!_dataChanged) return;
    try {
      User? user = _auth.currentUser;
      bool isConnected = await checkInternetConnection();
      if (user != null && isConnected) {
        await _firestore.collection('users').doc(user.uid).update(_userData!);
        _dataChanged = false;
      }
    } catch (e) {
      _showToast('Failed to save data: $e', isError: true);
    }
  }

  Future<void> setGoal(String type, String goal, DateTime endDate) async {
    _userData!['${type}Goal'] = goal;
    _userData!['is${type.capitalize()}GoalActive'] = 'true';
    _userData!['${type}GoalEndDate'] = DateFormat('yyyy-MM-dd').format(endDate);
    _dataChanged = true;
    notifyListeners();
    await saveDataToFirestore();
    _showToast("${type.capitalize()} Goal Started!");
  }

  Future<void> resetGoal(String type) async {
    _userData!['${type}Goal'] = '0';
    _userData!['is${type.capitalize()}GoalActive'] = 'false';
    _userData!['${type}GoalEndDate'] = _getDefaultEndDate();
    _userData!['${type}Steps'] = '0';
    _dataChanged = true;
    notifyListeners();
    await saveDataToFirestore();
    _showToast("${type.capitalize()} Goal Was Reset!");
  }

  Future<void> updateSteps(String type, int newStepCount) async {
    int currentSteps = int.parse(_userData!['${type}Steps']);
    int stepsDifference = newStepCount - currentSteps;

    if (stepsDifference > 0) {
      // Fetch the current group mission status
      String? currentMissionId = _userData!['currentGroupMissionId'];
      if (currentMissionId != null) {
        final missionDoc = await _firestore
            .collection('group_missions')
            .doc(currentMissionId)
            .get();

        if (missionDoc.exists && missionDoc.data()?['status'] != 'active') {
          // If the mission is not active, do not increment groupMissionSteps
          return;
        }
      }

      // Increment steps for the specific activity type
      _userData!['${type}Steps'] = (currentSteps + stepsDifference).toString();
      _userData!['totalSteps'] =
          (int.parse(_userData!['totalSteps']) + stepsDifference).toString();

      // Increment group mission steps only for active missions
      if (currentMissionId != null) {
        _userData!['groupMissionSteps'] =
            (int.parse(_userData!['groupMissionSteps']) + stepsDifference)
                .toString();
      }

      // Increment mission steps only if the mission isn't completed
      if (_userData!['isMissionCompleted'] == 'false') {
        _userData!['missionSteps'] =
            (int.parse(_userData!['missionSteps']) + stepsDifference)
                .toString();
      }

      _dataChanged = true;
      notifyListeners();
      await checkMissionCompletion();
      await checkGoalCompletion(type);
    }
  }

  Future<void> checkMissionCompletion() async {
    if (_userData == null ||
        _missionData == null ||
        _userData!['isMissionCompleted'] == 'true') return;

    int userMissionSteps = int.parse(_userData!['missionSteps']);
    int missionSteps = int.parse(_missionData!['steps']);
    int missionReward = int.parse(_missionData!['reward']);
    DateTime missionEndDate = DateTime.parse(_missionData!['endDate']);
    DateTime now = DateTime.now();

    // Add a check for user's account creation date
    DateTime userCreationDate = _auth.currentUser!.metadata.creationTime ?? now;

    bool missionCompleted = userMissionSteps >= missionSteps;
    bool missionEnded = now.isAfter(missionEndDate);

    if (missionCompleted ||
        (missionEnded && userCreationDate.isBefore(missionEndDate))) {
      int rewardPoints = missionCompleted
          ? missionReward
          : (userMissionSteps / missionSteps * missionReward).round();
      _updateUserDataAfterMission(rewardPoints);
      _showToast(_getMissionCompletionMessage(
        userMissionSteps,
        missionSteps,
        rewardPoints,
        missionCompleted,
      ));
    } else if (missionEnded) {
      // Mission ended, but user joined after it ended
      _userData!['isMissionCompleted'] = 'true';
      _dataChanged = true;
      notifyListeners();
      saveDataToFirestore();
      _showToast(
          "The current mission has already ended. Please wait for the next mission");
    }
  }

  void _updateUserDataAfterMission(int rewardPoints) {
    _userData!['totalPoints'] =
        (int.parse(_userData!['totalPoints']) + rewardPoints).toString();
    _userData!['missionsCompleted'] =
        (int.parse(_userData!['missionsCompleted']) + 1).toString();
    _userData!['isMissionCompleted'] = 'true';
    _dataChanged = true;
    notifyListeners();
    saveDataToFirestore();
  }

  String _getMissionCompletionMessage(int userMissionSteps, int missionSteps,
      int rewardPoints, bool missionCompleted) {
    return missionCompleted
        ? "Congratulations! You've completed the mission and earned $rewardPoints points!"
        : "The mission has ended. You've earned $rewardPoints points based on your progress!";
  }

  Future<void> checkGoalCompletion(String type) async {
    if (_userData!['is${type.capitalize()}GoalActive'] == 'false') return;

    int currentSteps = int.parse(_userData!['${type}Steps']);
    int goalSteps = int.parse(_userData!['${type}Goal']);
    DateTime endDate = DateTime.parse(_userData!['${type}GoalEndDate']);
    DateTime now = DateTime.now();

    if (currentSteps >= goalSteps || now.isAfter(endDate)) {
      // Determine the reward multiplier based on the activity type
      double rewardMultiplier = 1.0;
      if (type == 'walking') {
        rewardMultiplier = 1.1; // 10% reward bonus
      } else if (type == 'jogging') {
        rewardMultiplier = 1.2; // 20% reward bonus
      } else if (type == 'running') {
        rewardMultiplier = 1.3; // 30% reward bonus
      }

      int maxReward = (goalSteps * rewardMultiplier).round();
      int actualReward = (currentSteps >= goalSteps)
          ? maxReward
          : (maxReward * currentSteps / goalSteps).round();

      // Update user data with the calculated reward
      _userData!['totalPoints'] =
          (int.parse(_userData!['totalPoints']) + actualReward).toString();
      _userData!['${type}GoalEndDate'] = _getDefaultEndDate();
      _userData!['${type}Goal'] = '0';
      _userData!['is${type.capitalize()}GoalActive'] = 'false';
      _userData!['${type}Steps'] = '0';
      _dataChanged = true;
      notifyListeners();
      await saveDataToFirestore();

      // Show appropriate notification message
      _showToast(currentSteps >= goalSteps
          ? "Congratulations! You've completed your $type goal and earned $actualReward points!"
          : "Your $type goal period has ended. You've earned $actualReward points based on your progress!");
    }
  }

  Future<void> checkForNewAnnouncements() async {
    if (_userData == null) return;
    final lastViewedTime = _userData!['lastAnnouncementViewTime'] as Timestamp;
    final querySnapshot = await FirebaseFirestore.instance
        .collection('announcements')
        .where('timestamp', isGreaterThan: lastViewedTime)
        .get();
    int count = querySnapshot.docs.length;
    _unreadAnnouncements = count > 99 ? '99+' : count.toString();
    _dataChanged = true;
    notifyListeners();
  }

  Future<void> updateLastAnnouncementViewTime() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final now = Timestamp.now();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'lastAnnouncementViewTime': now});
      _userData!['lastAnnouncementViewTime'] = now;
      _unreadAnnouncements = '0';
      _dataChanged = true;
      notifyListeners();
    }
  }

  Future<void> checkForNewPosts() async {
    if (_userData == null) return;
    final lastViewedTime = _userData!['lastPostViewTime'] as Timestamp? ??
        Timestamp.fromDate(DateTime(2000));
    final querySnapshot = await FirebaseFirestore.instance
        .collection('posts')
        .where('timestamp', isGreaterThan: lastViewedTime)
        .get();
    int count = querySnapshot.docs.length;
    _unreadPosts = count > 99 ? '99+' : count.toString();
    _dataChanged = true;
    notifyListeners();
  }

  Future<void> updateLastPostViewTime() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final now = Timestamp.now();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'lastPostViewTime': now});
      _userData!['lastPostViewTime'] = now;
      _unreadPosts = '0';
      _dataChanged = true;
      notifyListeners();
    }
  }

  Future<void> updateUserData(Map<String, dynamic> newData) async {
    _userData?.addAll(newData);
    _dataChanged = true;
    notifyListeners();
    await saveDataToFirestore();
    checkForNewAnnouncements();
  }

  Future<void> refreshUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        _userData = doc.data() as Map<String, dynamic>;
        notifyListeners();
      }
    }
  }

  Future<void> updateUserProfile(String username, String photoURL) async {
    // Update the local user data
    _userData?['username'] = username;
    _userData?['photoURL'] = photoURL;
    notifyListeners();
  }

  Future<void> _showToast(String message, {bool isError = false}) async {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: isError ? Colors.red : Colors.black,
      textColor: Colors.white,
    );
  }
}

String _formatDate(dynamic date) {
  if (date == null) return _getDefaultEndDate();
  if (date is Timestamp) {
    return DateFormat('yyyy-MM-dd').format(date.toDate());
  }
  if (date is String) {
    try {
      return DateFormat('yyyy-MM-dd')
          .format(DateFormat('MMMM d, yyyy').parse(date));
    } catch (e) {
      try {
        return DateFormat('yyyy-MM-dd').format(DateTime.parse(date));
      } catch (e) {
        return _getDefaultEndDate();
      }
    }
  }
  return _getDefaultEndDate();
}

String _getDefaultEndDate() {
  return DateFormat('yyyy-MM-dd').format(DateTime.now());
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
