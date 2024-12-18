// ignore_for_file: deprecated_member_use

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:treestride/map_viewer.dart';

import 'bottom_navigation.dart';
import 'offline.dart';
import 'tree_gallery.dart';

class PlantedTrees extends StatefulWidget {
  const PlantedTrees({super.key});

  @override
  PlantedTreesState createState() => PlantedTreesState();
}

class PlantedTreesState extends State<PlantedTrees> {
  late Stream<List<ConnectivityResult>> _connectivityStream;
  List<Map<String, dynamic>> userPlantRequests = [];
  bool isLoading = false;
  bool hasMore = true;
  int pageSize = 5;
  DocumentSnapshot? lastDocument;

  @override
  void initState() {
    super.initState();
    _connectivityStream = Connectivity().onConnectivityChanged;
    _checkConnection();
    _fetchUserPlantRequests();
  }

  Future<void> _checkConnection() async {
    _connectivityStream.listen((List<ConnectivityResult> results) {
      if (results.contains(ConnectivityResult.none) || results.isEmpty) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const Offline()),
        );
      }
    });
  }

  Future<void> _openMap(String lat, String lng) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapPage(
          latitude: double.parse(lat),
          longitude: double.parse(lng),
        ),
      ),
    );
  }

  Future<void> _fetchUserPlantRequests() async {
    if (isLoading || !hasMore) return;

    setState(() {
      isLoading = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // Get the current user's username
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (!userDoc.exists) {
          _showToast('User document not found');
          return;
        }

        final username = userDoc.data()?['username'];
        if (username == null) {
          _showToast('Username not found in user document');
          return;
        }

        // Query only the plants that belong to the current user
        Query query = FirebaseFirestore.instance
            .collection('plant_requests')
            .where('username',
                isEqualTo: username) // Filter by current username
            .orderBy('timestamp', descending: true) // Sort by timestamp
            .limit(pageSize);

        if (lastDocument != null) {
          query = query.startAfterDocument(lastDocument!);
        }

        final querySnapshot = await query.get();

        if (querySnapshot.docs.isEmpty) {
          setState(() {
            hasMore = false;
            isLoading = false;
          });
          return;
        }

        lastDocument = querySnapshot.docs.last;

        final newRequests = querySnapshot.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();

        setState(() {
          userPlantRequests.addAll(newRequests);
          isLoading = false;
          hasMore = querySnapshot.docs.length >= pageSize;
        });
      } catch (e) {
        _showToast('Error fetching user plant requests: $e');
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshList() async {
    setState(() {
      userPlantRequests.clear();
      lastDocument = null;
      hasMore = true;
    });
    await _fetchUserPlantRequests();
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
    return MaterialApp(
      theme: ThemeData(
        textTheme: GoogleFonts.exo2TextTheme(
          Theme.of(context).textTheme,
        ),
        primaryTextTheme: GoogleFonts.exo2TextTheme(
          Theme.of(context).primaryTextTheme,
        ),
      ),
      home: PopScope(
        canPop: false,
        onPopInvoked: (didPop) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const TabNavigator(initialIndex: 4),
            ),
          );
        },
        child: Scaffold(
          backgroundColor: const Color(0xFFEFEFEF),
          appBar: AppBar(
            elevation: 2,
            backgroundColor: const Color(0xFFFEFEFE),
            shadowColor: Colors.grey.withOpacity(0.5),
            leading: IconButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TabNavigator(initialIndex: 4),
                  ),
                );
              },
              icon: const Icon(Icons.arrow_back),
              iconSize: 24,
            ),
            centerTitle: true,
            title: const Text(
              'MY TREES',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
            ),
          ),
          body: RefreshIndicator(
            color: const Color(0xFF08DAD6),
            onRefresh: _refreshList,
            child: userPlantRequests.isEmpty && !isLoading
                ? _buildEmptyState(context)
                : _buildTreeList(userPlantRequests),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.forest, size: 100, color: Color(0xFFBDBDBD)),
          SizedBox(height: 14),
          Text(
            'NOTHING IS HERE',
            style: TextStyle(fontSize: 20, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildTreeList(List<Map<String, dynamic>> plantRequests) {
    return ListView(
      padding: const EdgeInsets.only(top: 14, left: 14, right: 14),
      children: [
        ...plantRequests.map((request) => _buildTreeCard(request)),
        if (hasMore && !isLoading) _buildLoadMoreButton(),
        if (isLoading) _buildLoader(),
      ],
    );
  }

  Widget _buildTreeCard(Map<String, dynamic> request) {
    final bool isApproved = request['plantingStatus'] == 'approved';

    return Card(
      color: const Color(0xFFFEFEFE),
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    request['treeImage'] ?? '',
                    fit: BoxFit.cover,
                    width: 140,
                    height: 140,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request['treeName'] ?? 'Unknown Tree',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      request['treeType'] ?? 'Unknown',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: Color(0xFF08520B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(request['timestamp']),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF08520B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Planting Status: ${request['plantingStatus']}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isApproved ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (isApproved)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TreePictureUploadPage(
                              plantRequestId: request.containsKey('id')
                                  ? request['id']
                                  : '',
                              treeName: request['treeName'] ?? 'Unknown Tree',
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        backgroundColor: const Color(0xFF08DAD6),
                      ),
                      child: const Text(
                        "GALLERY",
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isApproved
                        ? () {
                            final lat = request['locationLat'];
                            final lng = request['locationLong'];
                            if (lat != null && lng != null) {
                              _openMap(lat, lng);
                            } else {
                              _showToast('Location not available');
                            }
                          }
                        : null, // Button is disabled when not approved
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      backgroundColor: const Color(0xFF08DAD6),
                      disabledBackgroundColor: Colors.grey,
                    ),
                    child: Text(
                      "LOCATION",
                      style: TextStyle(
                        color: isApproved ? Colors.black : Colors.white54,
                      ),
                    ),
                  ),
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF08DAD6),
            ),
            onPressed: _fetchUserPlantRequests,
            child: const Text(
              'LOAD MORE',
              style: TextStyle(
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoader() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(
              color: Color(0xFF08DAD6),
              strokeWidth: 6,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return 'Unknown';
    DateTime? date;
    if (dateValue is Timestamp) {
      date = dateValue.toDate();
    } else if (dateValue is String) {
      date = DateTime.tryParse(dateValue);
    }
    if (date == null) return 'Invalid Date';
    return DateFormat('MMM d, yyyy').format(date);
  }
}
