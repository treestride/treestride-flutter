import 'package:flutter/material.dart';
import 'workout.dart';

class StrengthWorkoutPlan extends StatelessWidget {
  const StrengthWorkoutPlan({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const Workout()),
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
                  builder: (context) => const Workout(),
                ),
              );
            },
            icon: const Icon(
              Icons.arrow_back,
            ),
            iconSize: 24,
          ),
          title: const Text(
            'STRENGTH WORKOUT',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(24.0),
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
                "assets/images/strength.jpg",
                width: double.infinity,
                height: 200,
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(14.0),
              child: Text(
                '8-Week Strength Building',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            Text(
              'This program is designed to build strength and muscle mass over 8 weeks. '
              'Follow the plan consistently, focusing on proper form and progressive overload.',
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
        const SizedBox(height: 24),
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
          const Icon(Icons.fitness_center, color: Colors.black54, size: 14),
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
          'Upper Body',
          [
            'Bench Press: 4 sets x 6-8 reps',
            'Overhead Press: 3 sets x 8-10 reps',
            'Bent-over Rows: 4 sets x 6-8 reps',
            'Pull-ups or Lat Pulldowns: 3 sets x 8-10 reps',
            'Dips: 3 sets x 8-10 reps',
            'Face Pulls: 3 sets x 12-15 reps',
          ]
        );
      case 2:
        return (
          'Lower Body',
          [
            'Squats: 4 sets x 6-8 reps',
            'Romanian Deadlifts: 3 sets x 8-10 reps',
            'Leg Press: 3 sets x 10-12 reps',
            'Walking Lunges: 3 sets x 10 reps per leg',
            'Calf Raises: 4 sets x 15-20 reps',
            'Plank: 3 sets x 30-60 seconds',
          ]
        );
      case 3:
        return (
          'Rest & Recovery',
          [
            'Light cardio (20-30 minutes)',
            'Dynamic stretching',
            'Foam rolling',
            'Mobility work',
          ]
        );
      case 4:
        return (
          'Upper Body',
          [
            'Incline Bench Press: 4 sets x 6-8 reps',
            'Seated Cable Rows: 4 sets x 8-10 reps',
            'Dumbbell Shoulder Press: 3 sets x 8-10 reps',
            'Chin-ups: 3 sets x max reps',
            'Tricep Pushdowns: 3 sets x 10-12 reps',
            'Bicep Curls: 3 sets x 10-12 reps',
          ]
        );
      case 5:
        return (
          'Lower Body',
          [
            'Deadlifts: 4 sets x 6-8 reps',
            'Front Squats: 3 sets x 8-10 reps',
            'Bulgarian Split Squats: 3 sets x 10 reps per leg',
            'Leg Curls: 3 sets x 10-12 reps',
            'Standing Calf Raises: 4 sets x 15-20 reps',
            'Hanging Leg Raises: 3 sets x 10-15 reps',
          ]
        );
      case 6:
        return (
          'Upper Body (Light)',
          [
            'Push-ups: 3 sets x 12-15 reps',
            'Inverted Rows: 3 sets x 10-12 reps',
            'Lateral Raises: 3 sets x 12-15 reps',
            'Band Pull-aparts: 3 sets x 15-20 reps',
            'Tricep Dips: 3 sets x 10-12 reps',
            'Hammer Curls: 3 sets x 10-12 reps',
          ]
        );
      case 7:
        return (
          'Rest & Recovery',
          [
            'Complete rest or light activity',
            'Gentle yoga or stretching',
            'Meditation or mindfulness practice',
            'Plan and prep meals for the upcoming week',
          ]
        );
      default:
        return ('Rest', ['Error: Invalid day']);
    }
  }
}
