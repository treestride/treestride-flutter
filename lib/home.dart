import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:treestride/jogging.dart';
import 'package:treestride/running.dart';

import 'announcements.dart';
import 'fitness.dart';
import 'offline.dart';
import 'user_feed.dart';
import 'leaderboard.dart';
import 'login.dart';
import 'profile.dart';
import 'walking.dart';
import 'plant_tree.dart';
import 'user_data_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Home());
}

class Home extends StatelessWidget {
  const Home({super.key});

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
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late Stream<List<ConnectivityResult>> _connectivityStream;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
    _connectivityStream = Connectivity().onConnectivityChanged;
    _checkConnection();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.storage,
      Permission.activityRecognition,
      Permission.camera
    ].request();
  }

  Future<void> _initializeApp() async {
    final provider = Provider.of<UserDataProvider>(context, listen: false);
    try {
      await provider.fetchUserData();
      await provider.fetchMissionData();
      await provider.checkMissionCompletion();
      await provider.checkForNewAnnouncements();
      await provider.checkForNewPosts();
      await provider.initNotifications();
    } catch (error) {
      _showErrorToast("Initialization error: $error");
      Future.delayed(Duration.zero, () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const Login()),
        );
      });
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

  void _showUserProfile(UserDataProvider userDataProvider) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Container(
            height: 300,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 64,
                  backgroundColor: const Color(0xFF08DAD6),
                  child: CircleAvatar(
                    radius: 62,
                    backgroundImage: NetworkImage(
                      userDataProvider.userData!['photoURL'] ?? 'N/A',
                    ),
                    onBackgroundImageError: (error, stackTrace) => const Icon(
                      Icons.image,
                      size: 64,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  userDataProvider.userData!['username'] ?? 'N/A',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF08DAD6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    _auth.signOut();
                    Navigator.of(context).pop();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const Login(),
                      ),
                    );
                  },
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Sign Out",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.logout,
                        color: Colors.black,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF08DAD6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const Fitness(),
                      ),
                    );
                  },
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Switch Mode",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.shuffle,
                        color: Colors.black,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMissionInfo(UserDataProvider provider) {
    if (provider.userData?['isMissionCompleted'] == 'true') {
      return Container(
        height: 200,
        alignment: Alignment.center,
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
        child: const Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "NO ACTIVE MISSION",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 14),
              Text(
                "The current mission has ended. Please check back again later.",
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      alignment: Alignment.center,
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
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Text(
              "CURRENT MISSION",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            _buildMissionInfoRow("Steps Goal:",
                "${NumberFormat('#,###').format(int.parse(provider.missionData?['steps'] ?? 'N/A'))} steps"),
            const SizedBox(height: 10),
            _buildMissionInfoRow("Reward:",
                "${NumberFormat('#,###').format(int.parse(provider.missionData?['reward'] ?? 'N/A'))} points"),
            const SizedBox(height: 10),
            _buildMissionInfoRow(
                "End Date:", provider.missionData?['endDate'] ?? 'N/A'),
          ],
        ),
      ),
    );
  }

  Widget _buildMissionInfoRow(String label, String value) {
    if (label == "End Date:" && value != "N/A") {
      try {
        DateTime endDate = DateTime.parse(value);
        String formattedDate = DateFormat('MMMM d, yyyy').format(endDate);
        value = formattedDate;
      } catch (e) {
        _showErrorToast("Error parsing date: $e");
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(value, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildMissionProgress(UserDataProvider provider) {
    if (provider.userData?['isMissionCompleted'] == 'true') {
      return const SizedBox.shrink();
    }

    int missionSteps =
        int.tryParse(provider.userData?['missionSteps'] ?? '0') ?? 0;
    int totalMissionSteps =
        int.tryParse(provider.missionData?['steps'] ?? '0') ?? 1;
    double progress = missionSteps / totalMissionSteps;

    // Calculate the percentage and format it to 2 decimal places
    String percentageText = '${(progress * 100).toStringAsFixed(1)}%';

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Mission Progress: ',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              percentageText,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF08DAD6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          borderRadius: BorderRadius.circular(4),
          value: progress.clamp(0.0, 1.0),
          minHeight: 24,
          backgroundColor: Colors.grey[300],
          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF08DAD6)),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildExerciseChoices() {
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
      child: Column(
        children: [
          const Text(
            "CHOOSE EXERCISE",
            style: TextStyle(
              color: Colors.black,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const WalkingCounter(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF08DAD6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Image.asset(
                    "assets/images/walking.png",
                    height: 48,
                    width: 48,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "WALKING",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const JoggingCounter(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF08DAD6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Image.asset(
                    "assets/images/jogging.png",
                    height: 48,
                    width: 48,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "JOGGING",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const RunningCounter(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF08DAD6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Image.asset(
                    "assets/images/running.png",
                    height: 48,
                    width: 48,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "RUNNING",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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

  @override
  Widget build(BuildContext context) {
    return Consumer<UserDataProvider>(
      builder: (context, userDataProvider, child) {
        if (userDataProvider.userData == null &&
            userDataProvider.missionData == null) {
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
              toolbarHeight: 64,
              centerTitle: true,
              title: Row(
                children: [
                  GestureDetector(
                    onTap: () => _showUserProfile(userDataProvider),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFF08DAD6),
                      child: CircleAvatar(
                        radius: 22,
                        backgroundImage: NetworkImage(
                          userDataProvider.userData!['photoURL'],
                        ),
                        onBackgroundImageError: (error, stackTrace) =>
                            const Icon(
                          Icons.image,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userDataProvider.userData!['username'],
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          textAlign: TextAlign.center,
                          "TOTAL POINTS: ${NumberFormat('#,###').format(int.parse(userDataProvider.userData!['totalPoints'] ?? 'N/A'))}",
                          style: const TextStyle(
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                Stack(
                  children: [
                    IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const AnnouncementPage(previousPage: Home()),
                          ),
                        );
                      },
                      icon: const Icon(Icons.notifications_active_outlined),
                    ),
                    if (userDataProvider.unreadAnnouncements != '0')
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            userDataProvider.unreadAnnouncements,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
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
                  Stack(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const UserFeedPage(),
                            ),
                          );
                        },
                        child: const Icon(
                          Icons.space_dashboard_outlined,
                          size: 30,
                        ),
                      ),
                      if (userDataProvider.unreadPosts != '0')
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              userDataProvider.unreadPosts,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const Leaderboard(),
                        ),
                      );
                    },
                    child: const Icon(
                      Icons.emoji_events_outlined,
                      size: 30,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {},
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
                          builder: (context) => const TreeShop(),
                        ),
                      );
                    },
                    child: const Icon(
                      Icons.park_outlined,
                      size: 30,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const Profile(),
                        ),
                      );
                    },
                    child: const Icon(
                      Icons.perm_identity_outlined,
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
                  child: userDataProvider.missionData == null
                      ? const CircularProgressIndicator(
                          color: Color(0xFF08DAD6),
                          strokeWidth: 6.0,
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Column(
                              children: [
                                _buildMissionInfo(userDataProvider),
                                const SizedBox(height: 24),
                                _buildMissionProgress(userDataProvider),
                              ],
                            ),
                            _buildExerciseChoices(),
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
