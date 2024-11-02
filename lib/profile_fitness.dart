// ignore_for_file: use_build_context_synchronously

import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'edit_profile.dart';
import 'user_data_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProfileFitness());
}

class ProfileFitness extends StatelessWidget {
  const ProfileFitness({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProfileFitnessHome();
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

  Future<bool> _checkConnectivity() async {
    try {
      final response = await http
          .head(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  void _navigateToEditProfile() async {
    if (await _checkConnectivity()) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const EditProfile(),
        ),
      );
    } else {
      _showToast("You are offline!");
      return;
    }

    if (!mounted) return;
    // Refresh data after returning
    Provider.of<UserDataProvider>(context, listen: false).refreshUserData();
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

  void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black,
      textColor: Colors.white,
    );
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
              automaticallyImplyLeading: false,
              backgroundColor: const Color(0xFFFEFEFE),
              shadowColor: Colors.grey.withOpacity(0.5),
              centerTitle: true,
              title: const Text(
                'PROFILE',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: [
                IconButton(
                  onPressed: _navigateToEditProfile,
                  icon: const Icon(Icons.edit),
                ),
              ],
            ),
            body: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
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
                                backgroundImage: CachedNetworkImageProvider(
                                  userDataProvider.userData!['photoURL'],
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
                      const SizedBox(height: 14),
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
                      const SizedBox(height: 14),
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
                      const SizedBox(height: 14),
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
