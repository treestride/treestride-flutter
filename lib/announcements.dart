import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'offline.dart';
import 'user_data_provider.dart';

class Announcement {
  final String id;
  final String title;
  final String content;
  final String? imageUrl;
  final GeoPoint? location;
  final DateTime timestamp;

  Announcement({
    required this.id,
    required this.title,
    required this.content,
    this.imageUrl,
    this.location,
    required this.timestamp,
  });

  factory Announcement.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // Handle the location field
    GeoPoint? locationGeoPoint;
    if (data['location'] != null) {
      if (data['location'] is GeoPoint) {
        locationGeoPoint = data['location'] as GeoPoint;
      } else if (data['location'] is Map) {
        // If location is stored as a Map, convert it to a GeoPoint
        Map<String, dynamic> locationMap =
            data['location'] as Map<String, dynamic>;
        locationGeoPoint = GeoPoint(
          locationMap['lat'] as double,
          locationMap['lng'] as double,
        );
      }
    }

    return Announcement(
      id: doc.id,
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      imageUrl: data['imageUrl'],
      location: locationGeoPoint,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }
}

class AnnouncementPage extends StatefulWidget {
  final Widget previousPage;
  const AnnouncementPage({super.key, required this.previousPage});

  @override
  AnnouncementPageState createState() => AnnouncementPageState();
}

class AnnouncementPageState extends State<AnnouncementPage> {
  late Stream<List<ConnectivityResult>> _connectivityStream;
  final int batchSize = 5;
  List<Announcement> announcements = [];
  bool isLoading = false;
  bool hasMore = true;
  DocumentSnapshot? lastDocument;

  @override
  void initState() {
    super.initState();
    _loadMoreAnnouncements();
    Provider.of<UserDataProvider>(context, listen: false)
        .updateLastAnnouncementViewTime();
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

  Future<void> _loadMoreAnnouncements() async {
    if (isLoading || !hasMore) return;

    setState(() {
      isLoading = true;
    });

    Query query = FirebaseFirestore.instance
        .collection('announcements')
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

    List<Announcement> newAnnouncements = querySnapshot.docs
        .map((doc) => Announcement.fromFirestore(doc))
        .toList();

    setState(() {
      announcements.addAll(newAnnouncements);
      lastDocument = querySnapshot.docs.last;
      isLoading = false;
      hasMore = querySnapshot.docs.length == batchSize;
    });
  }

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
      home: PopScope(
        canPop: false,
        onPopInvoked: (didPop) async {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => widget.previousPage,
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
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => widget.previousPage,
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
              'ANNOUNCEMENTS',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          body: announcements.isEmpty && !isLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.assignment_late,
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
                  padding: const EdgeInsets.only(
                    top: 24,
                    left: 24,
                    right: 24,
                  ),
                  itemCount: announcements.length + 1,
                  itemBuilder: (context, index) {
                    if (index < announcements.length) {
                      return Column(
                        children: [
                          AnnouncementCard(
                            announcement: announcements[index],
                          ),
                          const SizedBox(height: 24)
                        ],
                      );
                    } else if (hasMore) {
                      return Column(
                        children: [
                          if (isLoading)
                            const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF08DAD6),
                                strokeWidth: 6.0,
                              ),
                            ),
                          if (!isLoading &&
                              hasMore &&
                              announcements.length >= batchSize)
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF08DAD6),
                              ),
                              onPressed: _loadMoreAnnouncements,
                              child: const Text(
                                'Load More',
                                style: TextStyle(
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          const SizedBox(height: 24)
                        ],
                      );
                    } else {
                      return const SizedBox.shrink();
                    }
                  },
                ),
        ),
      ),
    );
  }
}

class AnnouncementCard extends StatelessWidget {
  final Announcement announcement;

  const AnnouncementCard({super.key, required this.announcement});

  void _openInGoogleMaps() async {
    if (announcement.location != null) {
      final lat = announcement.location!.latitude;
      final lng = announcement.location!.longitude;
      final url = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$lat,$lng');

      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        throw 'Could not launch $url';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          announcement.imageUrl != ''
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    announcement.imageUrl!,
                    width: double.infinity,
                    fit: BoxFit.contain,
                  ),
                )
              : const SizedBox.shrink(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  announcement.title,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                announcement.content,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 14),
              if (announcement.location != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 150,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(
                          announcement.location!.latitude,
                          announcement.location!.longitude,
                        ),
                        initialZoom: 13.0,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                          subdomains: const ['a', 'b', 'c'],
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              width: 40.0,
                              height: 40.0,
                              point: LatLng(
                                announcement.location!.latitude,
                                announcement.location!.longitude,
                              ),
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.red,
                                size: 42,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _openInGoogleMaps,
                    icon: const Icon(Icons.map),
                    label: const Text(
                      'Open In Google Map',
                      style: TextStyle(
                        color: Colors.black,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF08DAD6),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Center(
                child: Text(
                  textAlign: TextAlign.center,
                  "Announced On: ${DateFormat.yMMMd().add_jm().format(announcement.timestamp)}",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
