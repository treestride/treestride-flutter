// ignore_for_file: use_build_context_synchronously

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'environmentalist.dart';

class GroupMissionsPage extends StatefulWidget {
  const GroupMissionsPage({super.key});

  @override
  GroupMissionsPageState createState() => GroupMissionsPageState();
}

class GroupMissionsPageState extends State<GroupMissionsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _currentMissionId;

  Future<void> _fetchCurrentMission() async {
    final userDoc =
        await _firestore.collection('users').doc(_auth.currentUser!.uid).get();
    setState(() {
      _currentMissionId = userDoc.data()?['currentGroupMissionId'];
    });
  }

  Future<void> _checkAndCompleteMission(String missionId) async {
    final missionDoc =
        await _firestore.collection('group_missions').doc(missionId).get();
    if (!missionDoc.exists) return;

    final missionData = missionDoc.data() as Map<String, dynamic>;
    final participants =
        List<String>.from(missionData['participantsJoined'] ?? []);
    final goal = missionData['goal'] ?? 1;

    // Calculate combined steps
    int combinedSteps = await _getCombinedSteps(participants);
    if (combinedSteps >= goal) {
      // Update mission status to completed
      await _firestore.collection('group_missions').doc(missionId).update({
        'status': 'completed',
      });

      // Reset user's data so they can join new mission
      for (String userId in participants) {
        final userRef = _firestore.collection('users').doc(userId);

        // Reset user's mission data
        await userRef.update({
          'currentGroupMissionId': FieldValue.delete(),
          'groupMissionSteps': 0,
        });
      }

      // Create plant requests for each participant
      for (String userId in participants) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;

          try {
            // Create a new document in "plant_requests"
            final documentRef = _firestore.collection('plant_requests').doc();
            await documentRef.set({
              'id': documentRef.id,
              'userId': userId,
              'username': userData['username'] ?? 'Unknown',
              'treeName': missionData['treeName'],
              'treeType': missionData['treeType'],
              'treeImage': missionData['treeImage'],
              'plantingStatus': 'pending',
              'locationLong': '',
              'locationLat': '',
              'timestamp': FieldValue.serverTimestamp(),
            });

            // Increment totalTrees for the participant
            final userRef = _firestore.collection('users').doc(userId);
            final currentTotalTrees = int.parse(userData['totalTrees'] ?? '0');
            await userRef.update({
              'totalTrees': (currentTotalTrees + 1).toString(),
            });
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("Error processing plant request for $userId: $e"),
            ));
          }
        }
      }

      // Notify the user
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Mission completed! Planting requests success."),
      ));
    }
  }

  Future<void> _joinMission(
      String missionId, Map<String, dynamic> missionData) async {
    if (_currentMissionId != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("You can only join one mission at a time."),
      ));
      return;
    }

    final participantsJoined =
        List<String>.from(missionData['participantsJoined'] ?? []);
    final maxParticipants = missionData['participants'];

    if (participantsJoined.length >= maxParticipants) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("This mission is already full."),
      ));
      return;
    }

    participantsJoined.add(_auth.currentUser!.uid);

    await _firestore.collection('group_missions').doc(missionId).update({
      'participantsJoined': participantsJoined,
    });

    await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
      'currentGroupMissionId': missionId,
      'groupMissionSteps': 0,
    });

    // Check if the mission is now full
    if (participantsJoined.length == maxParticipants) {
      await _firestore.collection('group_missions').doc(missionId).update({
        'status': 'active',
      });
    }

    setState(() {
      _currentMissionId = missionId;
    });

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("Successfully joined the mission."),
    ));
  }

  Future<void> _showParticipantDetails(String missionId) async {
    final missionDoc =
        await _firestore.collection('group_missions').doc(missionId).get();
    final participants =
        List<String>.from(missionDoc.data()?['participantsJoined'] ?? []);

    List<Map<String, dynamic>> participantDetails = [];

    for (String userId in participants) {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        participantDetails.add({
          'username': userData['username'] ?? 'Unknown',
          'groupMissionSteps': userData['groupMissionSteps'] ?? 0,
        });
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.green.shade50,
                  Colors.green.shade100,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Custom Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 24,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade200,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Text(
                    "PARTICIPANTS",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade900,
                    ),
                  ),
                ),

                // Participants List
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: participantDetails.length,
                    separatorBuilder: (context, index) => Divider(
                      color: Colors.green.shade300,
                      thickness: 1,
                    ),
                    itemBuilder: (context, index) {
                      final participant = participantDetails[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: Colors.green.shade200,
                          child: Text(
                            participant['username'][0].toUpperCase(),
                            style: TextStyle(
                              color: Colors.green.shade900,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          participant['username'],
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade800,
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Text(
                            "Steps: ${participant['groupMissionSteps']}",
                            style: TextStyle(
                              color: Colors.green.shade900,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Close Button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text(
                      "Close",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMissionTile(DocumentSnapshot missionDoc) {
    final missionData = missionDoc.data() as Map<String, dynamic>;
    final participantsJoined =
        List<String>.from(missionData['participantsJoined'] ?? []);
    final isFull = participantsJoined.length >= missionData['participants'];
    final goal = missionData['goal'] ?? 1;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFEFEFE),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0xFFD4D4D4),
              blurRadius: 2,
              blurStyle: BlurStyle.outer,
            )
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFEFEFE),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mission Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Group Mission",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: missionData['status'] == 'active'
                            ? Colors.green.shade200
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        missionData['status'].toString().toUpperCase(),
                        style: const TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                // Mission Details
                Row(
                  children: [
                    // Tree Image
                    Hero(
                      tag: missionDoc.id,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: CachedNetworkImage(
                          imageUrl: missionData['treeImage'],
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              const CircularProgressIndicator(),
                          errorWidget: (context, url, error) =>
                              const Icon(Icons.error),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${missionData['goal']} Steps",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                          const Text(
                            "Mission Goal",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Tree Reward: ${missionData['treeName']}",
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Mission Participants: ${participantsJoined.length}/${missionData['participants']}",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Progress Indicator
                FutureBuilder<int>(
                  future: _getCombinedSteps(participantsJoined),
                  builder: (context, snapshot) {
                    final combinedSteps = snapshot.data ?? 0;
                    final progress = (combinedSteps / goal).clamp(0.0, 1.0);

                    // Trigger mission completion check
                    if (combinedSteps >= goal) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _checkAndCompleteMission(missionDoc.id);
                      });
                    }

                    return Column(
                      children: [
                        LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey[300],
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF08DAD6),
                          ),
                          minHeight: 10,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Participants Porgress: $combinedSteps/${missionData['goal']}",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 15),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isFull || _currentMissionId != null
                            ? null
                            : () => _joinMission(missionDoc.id, missionData),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade400,
                        ),
                        child: Text(isFull ? "Mission Full" : "Join Mission"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _showParticipantDetails(missionDoc.id),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green.shade700,
                          side: BorderSide(color: Colors.green.shade700),
                        ),
                        child: const Text("Participants"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1),
    );
  }

  Future<int> _getCombinedSteps(List<String> participants) async {
    int totalSteps = 0;

    final missionDoc = await _firestore
        .collection('group_missions')
        .doc(_currentMissionId!)
        .get();
    if (missionDoc.exists && missionDoc.data()?['status'] != 'active') {
      return totalSteps; // Don't count steps if the mission is not active
    }

    for (String userId in participants) {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        totalSteps += int.parse(userDoc.data()?['groupMissionSteps']);
      }
    }
    return totalSteps;
  }

  @override
  void initState() {
    super.initState();
    _fetchCurrentMission();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const Environmentalist(),
          ),
        );
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFEFEFEF),
        appBar: AppBar(
          centerTitle: true,
          title: const Text(
            "GROUP MISSIONS",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          elevation: 2.0,
          backgroundColor: const Color(0xFFFEFEFE),
          shadowColor: Colors.grey.withOpacity(0.5),
          leading: IconButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const Environmentalist(),
                ),
              );
            },
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('group_missions').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF08DAD6),
                  strokeWidth: 6,
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Text(
                  "NOTHING IS HERE",
                  style: TextStyle(
                    color: Colors.green.shade800,
                    fontSize: 20,
                  ),
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.only(top: 14, left: 14, right: 14),
              children: snapshot.data!.docs.map(_buildMissionTile).toList(),
            );
          },
        ),
      ),
    );
  }
}
