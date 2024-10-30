import 'package:flutter/material.dart';
import 'bottom_navigation_fitness.dart';

class BalanceWorkoutPlan extends StatelessWidget {
  const BalanceWorkoutPlan({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const TabNavigatorFitness(initialIndex: 0),
          ),
        );
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFEFEFEF),
        appBar: AppBar(
          elevation: 2,
          backgroundColor: const Color(0xFFFEFEFE),
          shadowColor: Colors.grey.withOpacity(0.5),
          centerTitle: true,
          leading: IconButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const TabNavigatorFitness(initialIndex: 0),
                ),
              );
            },
            icon: const Icon(
              Icons.arrow_back,
            ),
            iconSize: 24,
          ),
          title: const Text(
            'BALANCE WORKOUT',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(14.0),
          children: [
            _buildIntroCard(),
            ...List.generate(7, (index) => _buildDayCard(index + 1)),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroCard() {
    return Container(
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
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.asset(
                fit: BoxFit.cover,
                "assets/images/balance.jpg",
                width: double.infinity,
                height: 200,
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(14.0),
              child: Text(
                '4-Week Balance Building',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            Text(
              'This program is designed to improve your balance and stability over 4 weeks. '
              'Focus on maintaining proper form and gradually increasing the difficulty of exercises. '
              'Always ensure a safe environment when performing balance exercises.',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayCard(int day) {
    final (title, exercises) = _getWorkoutForDay(day);

    return Column(
      children: [
        const SizedBox(height: 14),
        Container(
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
              Padding(
                padding: const EdgeInsets.only(top: 14, left: 14),
                child: Text(
                  'Day $day - $title',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: exercises
                      .map((exercise) => _buildExerciseItem(exercise))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExerciseItem(String exercise) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.balance, color: Colors.black54, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              exercise,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  (String, List<String>) _getWorkoutForDay(int day) {
    switch (day) {
      case 1:
        return (
          'Static Balance',
          [
            'Warm-up: 10 minutes light cardio',
            'Single Leg Stand: 3 sets x 30 seconds each leg',
            'Tree Pose: 3 sets x 30 seconds each leg',
            'Stork Stand: 3 sets x 20 seconds each leg',
            'Tandem Stand: 3 sets x 30 seconds',
            'Cool-down: 5 minutes light stretching',
          ]
        );
      case 2:
        return (
          'Dynamic Balance',
          [
            'Warm-up: 10 minutes dynamic stretching',
            'Walking Heel-to-Toe: 3 sets x 20 steps',
            'Lateral Shuffle: 3 sets x 30 seconds',
            'Single Leg Hops: 3 sets x 10 hops each leg',
            'Stability Ball Knee Balances: 3 sets x 30 seconds',
            'Cool-down: 5 minutes light yoga',
          ]
        );
      case 3:
        return (
          'Strength & Balance',
          [
            'Warm-up: 10 minutes light cardio',
            'Single Leg Deadlifts: 3 sets x 10 reps each leg',
            'Pistol Squats (assisted if needed): 3 sets x 5 reps each leg',
            'Bosu Ball Squats: 3 sets x 15 reps',
            'Plank with Leg Lifts: 3 sets x 30 seconds',
            'Cool-down: 5 minutes static stretching',
          ]
        );
      case 4:
        return (
          'Yoga for Balance',
          [
            'Sun Salutations: 5 rounds',
            'Warrior III Pose: Hold for 30 seconds each side, 3 sets',
            'Half Moon Pose: Hold for 20 seconds each side, 3 sets',
            'Eagle Pose: Hold for 30 seconds each side, 3 sets',
            'Dancer\'s Pose: Hold for 20 seconds each side, 3 sets',
            'Cool-down: 10 minutes Savasana',
          ]
        );
      case 5:
        return (
          'Functional Balance',
          [
            'Warm-up: 10 minutes light cardio',
            'Stability Ball Pass: 3 sets x 20 passes',
            'Medicine Ball Chops: 3 sets x 15 reps each side',
            'Bosu Ball Mountain Climbers: 3 sets x 30 seconds',
            'Single Leg Romanian Deadlift to Row: 3 sets x 10 reps each side',
            'Cool-down: 5 minutes light stretching',
          ]
        );
      case 6:
        return (
          'Balance Challenge',
          [
            'Warm-up: 10 minutes dynamic stretching',
            'Obstacle Course: Set up a course with various balance challenges',
            'Single Leg Balance with Eyes Closed: 3 sets x 20 seconds each leg',
            'Tightrope Walk: 3 sets x 20 steps',
            'Stability Ball Plank to Pike: 3 sets x 10 reps',
            'Cool-down: 5 minutes light yoga',
          ]
        );
      case 7:
        return (
          'Rest & Recovery',
          [
            'Light stretching or gentle yoga',
            'Self-massage or foam rolling',
            'Mindfulness or meditation practice',
            'Review progress and set goals for the next week',
          ]
        );
      default:
        return ('Rest', ['Error: Invalid day']);
    }
  }
}
