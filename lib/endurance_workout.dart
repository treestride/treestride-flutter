import 'package:flutter/material.dart';
import 'workout.dart';

class EnduranceWorkoutPlan extends StatelessWidget {
  const EnduranceWorkoutPlan({super.key});

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
            'ENDURANCE WORKOUT',
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
        padding: const EdgeInsets.only(bottom: 14, left: 14, right: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Padding(
              padding: EdgeInsets.all(14.0),
              child: Text(
                '8-Week Endurance Building',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            Text(
              'This program is designed to improve your endurance and cardiovascular fitness over 8 weeks. '
              'Follow the plan consistently, focusing on maintaining good form and gradually increasing duration and intensity.',
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
                    fontSize: 20,
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
          const Icon(Icons.directions_run, color: Colors.black54, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              exercise,
              style: const TextStyle(fontSize: 16),
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
          'Cardio & Core',
          [
            'Warm-up: 10 minutes light jog',
            'Interval Run: 6 x (2 min high intensity, 1 min recovery)',
            'Bodyweight Squats: 3 sets x 20 reps',
            'Plank: 3 sets x 45-60 seconds',
            'Mountain Climbers: 3 sets x 30 seconds',
            'Cool-down: 10 minutes light jog and stretching',
          ]
        );
      case 2:
        return (
          'Strength Endurance',
          [
            'Warm-up: 10 minutes jump rope',
            'Circuit (3 rounds, 45 seconds each, 15 seconds rest):',
            '- Push-ups',
            '- Lunges',
            '- Dips',
            '- High Knees',
            '- Burpees',
            'Cool-down: 10 minutes light cardio and stretching',
          ]
        );
      case 3:
        return (
          'Active Recovery',
          [
            'Light jog or brisk walk: 30-40 minutes',
            'Dynamic stretching',
            'Foam rolling',
            'Yoga or mobility work',
          ]
        );
      case 4:
        return (
          'HIIT & Core',
          [
            'Warm-up: 10 minutes light cardio',
            'HIIT: 10 x (30 seconds max effort, 30 seconds rest)',
            'Bicycle Crunches: 3 sets x 20 reps',
            'Russian Twists: 3 sets x 30 reps',
            'Leg Raises: 3 sets x 15 reps',
            'Cool-down: 10 minutes light cardio and stretching',
          ]
        );
      case 5:
        return (
          'Endurance Run',
          [
            'Warm-up: 10 minutes light jog and dynamic stretching',
            'Long Slow Distance Run: 45-60 minutes at conversational pace',
            'Cool-down: 10 minutes walking and static stretching',
          ]
        );
      case 6:
        return (
          'Cross-Training',
          [
            'Choose one:',
            '- Swimming: 30-40 minutes',
            '- Cycling: 45-60 minutes',
            '- Rowing: 30-40 minutes',
            'Bodyweight exercises (3 sets each):',
            '- 15 Tricep Dips',
            '- 15 Step-ups per leg',
            '- 10 Decline Push-ups',
            'Cool-down: 10 minutes light cardio and stretching',
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
