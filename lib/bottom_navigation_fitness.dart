import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'fitness.dart';
import 'profile_fitness.dart';
import 'user_data_provider.dart';
import 'workout.dart';

class TabNavigatorFitness extends StatefulWidget {
  final int initialIndex;
  const TabNavigatorFitness({super.key, this.initialIndex = 1});

  @override
  TabNavigatorFitnessState createState() => TabNavigatorFitnessState();
}

class TabNavigatorFitnessState extends State<TabNavigatorFitness>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
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
        return MaterialApp(
          theme: ThemeData(
            textTheme: GoogleFonts.exo2TextTheme(
              Theme.of(context).textTheme,
            ),
            primaryTextTheme: GoogleFonts.exoTextTheme(
              Theme.of(context).primaryTextTheme,
            ),
          ),
          home: Scaffold(
            body: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(), // Disable swipe
              children: const [
                Workout(),
                FitnessMode(),
                ProfileFitness(),
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
                tabs: const [
                  Tab(icon: Icon(Icons.fitness_center_outlined)),
                  Tab(icon: Icon(Icons.directions_walk_outlined)),
                  Tab(icon: Icon(Icons.person_outline)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
