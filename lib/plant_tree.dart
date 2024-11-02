// ignore_for_file: use_build_context_synchronously

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:treestride/user_data_provider.dart';

import 'offline.dart';
import 'certificate.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (context) => UserDataProvider(),
      child: const TreeShop(),
    ),
  );
}

class TreeShop extends StatelessWidget {
  const TreeShop({super.key});

  @override
  Widget build(BuildContext context) {
    return const TreeShopHome();
  }
}

class TreeShopHome extends StatefulWidget {
  const TreeShopHome({super.key});

  @override
  TreeShopHomeState createState() => TreeShopHomeState();
}

class TreeShopHomeState extends State<TreeShopHome> {
  late Stream<List<ConnectivityResult>> _connectivityStream;
  bool isInitialLoad = true;
  List<QueryDocumentSnapshot> trees = [];
  bool isLoading = false;
  bool hasMore = true;
  final int batchSize = 5;
  DocumentSnapshot? lastDocument;

  final Map<String, Color> treeTypeColors = {
    'non-bearing': Colors.orange[300]!,
    'bearing': Colors.green[700]!,
  };

  Color getTreeTypeColor(String treeType) {
    return treeTypeColors[treeType] ?? Colors.grey[400]!;
  }

  @override
  void initState() {
    super.initState();
    _connectivityStream = Connectivity().onConnectivityChanged;
    _checkConnection();
    _loadInitialBatch();
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

  Future<void> _loadInitialBatch() async {
    await _loadMoreTrees();
  }

  Future<void> _loadMoreTrees() async {
    if (isLoading || !hasMore) return;

    setState(() {
      isLoading = true;
    });

    try {
      Query query = FirebaseFirestore.instance
          .collection('trees')
          .orderBy('timestamp', descending: true)
          .limit(batchSize);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument!);
      }

      QuerySnapshot querySnapshot = await query.get();

      if (querySnapshot.docs.isEmpty) {
        setState(() {
          hasMore = false;
          isLoading = false;
        });
        return;
      }

      setState(() {
        trees.addAll(querySnapshot.docs);
        lastDocument = querySnapshot.docs.last;
        isLoading = false;
        hasMore = querySnapshot.docs.length >= batchSize;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _showToast('Error loading trees: $e');
    }
  }

  Future<bool> _checkYearlyTreeLimit() async {
    try {
      // Get current user ID
      final userId = FirebaseAuth.instance.currentUser!.uid;

      // Get current timestamp and start of year
      final now = DateTime.now();
      final startOfYear = DateTime(now.year, 1, 1);

      // Query plant_requests for this user in the current year
      final querySnapshot = await FirebaseFirestore.instance
          .collection('plant_requests')
          .where('userId', isEqualTo: userId)
          .where('timestamp', isGreaterThanOrEqualTo: startOfYear)
          .get();

      // Count the number of trees planted this year
      final treesPlantedThisYear = querySnapshot.docs.length;

      // Check if user has reached the limit
      if (treesPlantedThisYear >= 2) {
        _showToast(
            'You have reached the limit of 2 trees that you can plant per year');
        return false;
      }
      return true;
    } catch (e) {
      _showToast('Error checking yearly limit: $e');
      return false;
    }
  }

  Future<void> _processTreePlanting(
    String treeId,
    Map<String, dynamic> treeData,
  ) async {
    // Check yearly limit
    bool canPlantTree = await _checkYearlyTreeLimit();
    if (!canPlantTree) {
      return;
    }

    final userDataProvider =
        Provider.of<UserDataProvider>(context, listen: false);
    final userData = userDataProvider.userData;

    if (userData == null) {
      _showToast('User data not available');
      return;
    }

    int availableTrees = int.parse(treeData['availableTrees']);
    int treeCost = int.parse(treeData['treeCost']);
    int userPoints = int.parse(userData['totalPoints']);

    if (availableTrees <= 0) {
      _showToast('Sorry, this tree is out of stock!');
      return;
    }

    if (userPoints < treeCost) {
      _showToast('Not enough points!');
      return;
    }

    // Deduct points and update user data
    int newPoints = userPoints - treeCost;
    int newTotalTrees = int.parse(userData['totalTrees']) + 1;
    int newCertificates = int.parse(userData['certificates']) + 1;

    // Update Firestore
    try {
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Update user data
        transaction.update(userRef, {
          'totalPoints': newPoints.toString(),
          'totalTrees': newTotalTrees.toString(),
          'certificates': newCertificates.toString(),
        });

        // Update tree stock
        final treeRef =
            FirebaseFirestore.instance.collection('trees').doc(treeId);
        transaction.update(treeRef, {
          'availableTrees': (availableTrees - 1).toString(),
        });

        // Add plant request
        transaction.set(
          FirebaseFirestore.instance.collection('plant_requests').doc(),
          {
            'timestamp': FieldValue.serverTimestamp(),
            'userId': FirebaseAuth.instance.currentUser!.uid,
            'username': userData['username'],
            'photoURL': userData['photoURL'],
            'treeImage': treeData['image'],
            'treeName': treeData['name'],
            'treeType': treeData['type'],
            'treeCost': treeData['treeCost'],
            'plantingStatus': 'pending',
            'locationLong': '',
            'locationLat': '',
          },
        );
      });

      // Update local state
      userDataProvider.updateUserData({
        'totalPoints': newPoints.toString(),
        'totalTrees': newTotalTrees.toString(),
        'certificates': newCertificates.toString(),
      });

      // Navigate to Certificate page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => Certificate(
            treeData: treeData,
            userTotalTrees: newTotalTrees,
            userCertificates: newCertificates,
            userProfile: userData['photoURL'],
            username: userData['username'],
          ),
        ),
      );
      _showToast('Success!');
    } catch (e) {
      _showToast('Error processing tree planting: $e');
    }
  }

  void _showDescriptionDialog(
      BuildContext context, String treeName, String description) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFEFEFE),
          title: Text(
            textAlign: TextAlign.center,
            treeName,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Container(
            height: 120,
            alignment: Alignment.center,
            child: SingleChildScrollView(
              child: Text(
                textAlign: TextAlign.center,
                description,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          actions: <Widget>[
            SizedBox(
              width: double.infinity,
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF08DAD6),
                ),
                child: const Text(
                  "CLOSE",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showPlantConfirmation(
      String treeName, String treeCost, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFEFEFE),
          title: Text(
            "Plant $treeName",
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              color: Colors.black,
            ),
          ),
          content: Text(
            textAlign: TextAlign.center,
            "Are you sure you want to plant $treeName for the cost of ${NumberFormat('#,###').format(int.parse(treeCost))} points?",
            style: const TextStyle(
              color: Colors.black,
              fontSize: 14,
            ),
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
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF08DAD6),
                surfaceTintColor: const Color(0xFF08DAD6),
              ),
              child: const Text(
                'Confirm',
                style: TextStyle(
                  color: Colors.black,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                onConfirm();
              },
            ),
          ],
          actionsAlignment: MainAxisAlignment.spaceAround,
        );
      },
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
              _showToast("Closing Error: $error");
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
                'PLANT TREE',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            body: userDataProvider.userData == null
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF08DAD6),
                      strokeWidth: 6.0,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Text(
                          "Available Points: ${NumberFormat('#,###').format(int.parse(userDataProvider.userData!['totalPoints'] ?? '0'))}",
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: trees.isEmpty
                            ? const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.park,
                                      size: 100,
                                      color: Color(0xFFBDBDBD),
                                    ),
                                    SizedBox(height: 14),
                                    Text(
                                      'NOTHING IS HERE',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: trees.length + (hasMore ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == trees.length) {
                                    return _buildLoadMoreButton();
                                  }
                                  final treeDocument = trees[index];
                                  final treeData = treeDocument.data()
                                      as Map<String, dynamic>;
                                  final treeId = treeDocument.id;
                                  return _buildTreeCard(
                                    context,
                                    treeData,
                                    treeId,
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildLoadMoreButton() {
    if (!hasMore) return const SizedBox.shrink();
    return isLoading
        ? const Padding(
            padding: EdgeInsets.all(14.0),
            child: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF08DAD6),
                strokeWidth: 6.0,
              ),
            ),
          )
        : Padding(
            padding: const EdgeInsets.all(14.0),
            child: SizedBox(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF08DAD6),
                ),
                onPressed: _loadMoreTrees,
                child: const Text(
                  'Load More',
                  style: TextStyle(
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          );
  }

  Widget _buildTreeCard(
      BuildContext context, Map<String, dynamic> treeData, String treeId) {
    Color treeColor = getTreeTypeColor(treeData['type']);

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(left: 14, right: 14),
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
            border: Border.all(color: treeColor, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildTreeImage(treeData['image'], treeColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            treeData['name'],
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: treeColor, // Use tree type color for name
                            ),
                          ),
                          const SizedBox(height: 4),
                          _buildInfoRow(
                              'Type:', '${treeData['type']}', treeColor),
                          const SizedBox(height: 4),
                          _buildInfoRow(
                              'Cost:',
                              '${NumberFormat('#,###').format(int.parse(treeData['treeCost']))} Pts',
                              null),
                          const SizedBox(height: 4),
                          _buildInfoRow(
                              'Available:',
                              NumberFormat('#,###').format(
                                  int.parse(treeData['availableTrees'])),
                              null),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _buildButton(
                      'DESCRIPTION',
                      treeData['name'],
                      treeData['treeCost'],
                      () => _showDescriptionDialog(
                        context,
                        treeData['name'],
                        treeData['description'],
                      ),
                      treeColor,
                    ),
                    const SizedBox(width: 14),
                    _buildButton(
                      'PLANT',
                      treeData['name'],
                      treeData['treeCost'],
                      () => _processTreePlanting(treeId, treeData),
                      treeColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _buildTreeImage(String? imageUrl, Color treeColor) {
    return imageUrl != null && imageUrl.isNotEmpty
        ? Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: treeColor, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                width: 100,
                height: 100,
                imageUrl,
                fit: BoxFit.cover,
              ),
            ),
          )
        : Icon(
            Icons.image,
            size: 100,
            color: treeColor,
          );
  }

  Widget _buildInfoRow(String label, String value, Color? color) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildButton(String label, String treeName, String treeCost,
      VoidCallback onPressed, Color treeColor) {
    IconData iconData;
    if (label == 'DESCRIPTION') {
      iconData = FontAwesomeIcons.circleInfo;
    } else if (label == 'PLANT') {
      iconData = FontAwesomeIcons.seedling;
    } else {
      iconData = FontAwesomeIcons.circle;
    }

    return Expanded(
      child: ElevatedButton(
        onPressed: () {
          if (label == 'PLANT') {
            _showPlantConfirmation(treeName, treeCost, () {
              onPressed();
            });
          } else {
            onPressed();
          }
        },
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          backgroundColor: treeColor,
          foregroundColor: treeColor,
        ),
        child: Icon(
          iconData,
          color: Colors.black,
          size: 24,
        ),
      ),
    );
  }
}
