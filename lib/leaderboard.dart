// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'offline.dart';
import 'user_feed.dart';
import 'home.dart';
import 'profile.dart';
import 'plant_tree.dart';
import 'user_data_provider.dart';

class Leaderboard extends StatelessWidget {
  const Leaderboard({super.key});

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
      home: const LeaderboardHome(),
    );
  }
}

class LeaderboardHome extends StatefulWidget {
  const LeaderboardHome({super.key});

  @override
  LeaderboardHomeState createState() => LeaderboardHomeState();
}

class LeaderboardHomeState extends State<LeaderboardHome> {
  late Stream<List<ConnectivityResult>> _connectivityStream;
  @override
  void initState() {
    super.initState();
    _connectivityStream = Connectivity().onConnectivityChanged;
    _checkConnection();
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
        onPopInvoked: (didPop) async {
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
            elevation: 2,
            backgroundColor: const Color(0xFFFEFEFE),
            shadowColor: Colors.grey.withOpacity(0.5),
            leading: IconButton(
              onPressed: () {
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
              'LEADERBOARD',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
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
                  onTap: () {},
                  child: const Icon(
                    Icons.emoji_events_outlined,
                    size: 30,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const Home(),
                      ),
                    );
                  },
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
          body: const LeaderboardList(),
        ),
      );
    });
  }
}

class LeaderboardList extends StatefulWidget {
  const LeaderboardList({super.key});

  @override
  LeaderboardListState createState() => LeaderboardListState();
}

class LeaderboardListState extends State<LeaderboardList> {
  final List<Map<String, dynamic>> _users = [];
  bool _isLoading = false;
  bool _hasMore = true;
  final int _batchSize = 10;

  String _formatNumber(String value) {
    int? number = int.tryParse(value);
    if (number == null) return value;

    if (number >= 1000000000) {
      return '${(number / 1000000000).toStringAsFixed(1)}B';
    } else if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    } else {
      return number.toString();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadMoreUsers();
  }

  Future<void> _loadMoreUsers() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      Query query = FirebaseFirestore.instance
          .collection('users')
          .orderBy('totalSteps', descending: true)
          .limit(_batchSize);

      if (_users.isNotEmpty) {
        query = query.startAfter([_users.last['totalSteps']]);
      }

      final QuerySnapshot querySnapshot = await query.get();

      final List<Map<String, dynamic>> newUsers = querySnapshot.docs
          .map((doc) => {
                'username': doc['username'],
                'totalSteps': doc['totalSteps'].toString(),
                'photoURL': doc['photoURL'],
              })
          .toList();

      newUsers.sort((a, b) =>
          int.parse(b['totalSteps']).compareTo(int.parse(a['totalSteps'])));

      setState(() {
        _users.addAll(newUsers);
        _isLoading = false;
        _hasMore = newUsers.length == _batchSize && _users.length < 100;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error loading users: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_users.isNotEmpty) _buildTopThree(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            itemCount: _users.length + (_hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index < _users.length) {
                final user = _users[index];
                return index < _users.length.clamp(0, 3)
                    ? const SizedBox.shrink()
                    : _buildUserListItem(user, index);
              } else if (_hasMore) {
                return _buildLoadMoreIndicator();
              } else {
                return const SizedBox.shrink();
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTopThree() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.blue.shade100, Colors.white],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_users.length > 1)
            _buildTopUserWidget(_users[1], 2, Colors.grey.shade300),
          if (_users.isNotEmpty)
            _buildTopUserWidget(_users[0], 1, Colors.amber),
          if (_users.length > 2)
            _buildTopUserWidget(_users[2], 3, Colors.brown.shade300),
        ],
      ),
    );
  }

  Widget _buildTopUserWidget(Map<String, dynamic> user, int rank, Color color) {
    final double size = rank == 1 ? 120 : 100;
    final double avatarSize = rank == 1 ? 60 : 50;
    final double fontSize = rank == 1 ? 18 : 16;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: avatarSize / 1.85,
                backgroundColor: Colors.black12,
                child: CircleAvatar(
                  onBackgroundImageError: (error, stackTrace) => Icon(
                    Icons.image,
                    size: avatarSize / 2,
                  ),
                  radius: avatarSize / 2,
                  backgroundImage: NetworkImage(user['photoURL']),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                textAlign: TextAlign.center,
                user['username'],
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: fontSize,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                textAlign: TextAlign.center,
                '${_formatNumber((user['totalSteps']))} STEPS',
                style: TextStyle(fontSize: fontSize - 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Icon(Icons.emoji_events, color: color, size: 32),
        Text(
          textAlign: TextAlign.center,
          '#$rank',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: fontSize,
          ),
        ),
      ],
    );
  }

  Widget _buildUserListItem(Map<String, dynamic> user, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: Colors.black12,
            child: CircleAvatar(
              radius: 22,
              backgroundImage: NetworkImage(user['photoURL']),
              onBackgroundImageError: (error, stackTrace) => const Icon(
                Icons.image,
                size: 22,
              ),
            ),
          ),
          title: Text(
            user['username'],
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            '${NumberFormat('#,###').format(int.parse(user['totalSteps']))} STEPS',
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '#${index + 1}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadMoreIndicator() {
    return Center(
      child: _isLoading
          ? const CircularProgressIndicator(
              color: Color(0xFF08DAD6),
              strokeWidth: 6,
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: ElevatedButton(
                    onPressed: _loadMoreUsers,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF08DAD6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Load More',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
