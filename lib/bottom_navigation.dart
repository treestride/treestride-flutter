import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'user_data_provider.dart';
import 'user_feed.dart';
import 'leaderboard.dart';
import 'environmentalist.dart';
import 'plant_tree.dart';
import 'profile.dart';

class TabNavigator extends StatefulWidget {
  final int initialIndex;
  const TabNavigator({super.key, this.initialIndex = 2});

  @override
  TabNavigatorState createState() => TabNavigatorState();
}

class TabNavigatorState extends State<TabNavigator>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserDataProvider>(
      builder: (context, userDataProvider, child) {
        return Scaffold(
          body: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(), // Disable swipe
            children: const [
              UserFeedPage(),
              Leaderboard(),
              EnvironmentalistPage(),
              TreeShop(),
              Profile(),
            ],
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFEFEFE),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 2,
                  blurRadius: 2,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF08DAD6),
              unselectedLabelColor: Colors.black,
              indicatorColor: const Color(0xFF08DAD6),
              indicatorSize: TabBarIndicatorSize.tab,
              tabs: [
                Tab(
                  icon: Stack(
                    children: [
                      const Icon(Icons.view_agenda_outlined),
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
                ),
                const Tab(icon: Icon(Icons.emoji_events_outlined)),
                const Tab(icon: Icon(Icons.directions_walk_outlined)),
                const Tab(icon: Icon(Icons.park_outlined)),
                const Tab(icon: Icon(Icons.perm_identity_outlined)),
              ],
            ),
          ),
        );
      },
    );
  }
}
