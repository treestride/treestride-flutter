import 'package:flutter/material.dart';
import 'workout.dart';

class FlexibilityWorkoutPlan extends StatelessWidget {
  const FlexibilityWorkoutPlan({super.key});

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
            'FLEXIBILITY WORKOUT',
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
        padding: const EdgeInsets.only(bottom: 14, left: 14, right: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Padding(
              padding: EdgeInsets.all(14.0),
              child: Text(
                '4-Week Flexibility Program',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            Text(
              'This program is designed to improve your overall flexibility over 4 weeks. '
              'Focus on gentle stretching and gradually increasing your range of motion. '
              'Remember to breathe deeply and never force a stretch beyond your comfort level.',
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
          'Full Body Stretch',
          [
            'Warm-up: 5 minutes light cardio',
            'Standing forward bend: 3 sets x 30 seconds',
            'Cat-Cow stretch: 3 sets x 10 reps',
            'Chest and shoulder stretch: 3 sets x 30 seconds each side',
            'Seated forward bend: 3 sets x 30 seconds',
            'Cool-down: 5 minutes gentle walking'
          ]
        );
      case 2:
        return (
          'Lower Body Focus',
          [
            'Warm-up: 5 minutes dynamic stretching',
            'Lunges with twist: 3 sets x 10 reps each leg',
            'Pigeon pose: 3 sets x 30 seconds each leg',
            'Hamstring stretch: 3 sets x 30 seconds each leg',
            'Butterfly stretch: 3 sets x 30 seconds',
            'Cool-down: 5 minutes light yoga'
          ]
        );
      case 3:
        return (
          'Upper Body and Core',
          [
            'Warm-up: 5 minutes arm circles and shoulder rolls',
            'Triceps stretch: 3 sets x 30 seconds each arm',
            'Child\'s pose: 3 sets x 30 seconds',
            'Cobra pose: 3 sets x 15 seconds',
            'Thread the needle: 3 sets x 30 seconds each side',
            'Cool-down: 5 minutes gentle stretching'
          ]
        );
      case 4:
        return (
          'Dynamic Flexibility',
          [
            'Warm-up: 5 minutes light jogging',
            'Arm swings: 3 sets x 20 reps',
            'Leg swings: 3 sets x 15 reps each leg',
            'Walking lunges: 3 sets x 10 steps each leg',
            'World\'s greatest stretch: 3 sets x 5 reps each side',
            'Cool-down: 5 minutes static stretching'
          ]
        );
      case 5:
        return (
          'Yoga for Flexibility',
          [
            'Sun Salutations: 5 rounds',
            'Warrior I to Warrior II flow: 3 sets x 5 reps each side',
            'Triangle pose: Hold for 30 seconds each side, 3 sets',
            'Seated spinal twist: Hold for 30 seconds each side, 3 sets',
            'Reclined spinal twist: Hold for 30 seconds each side, 3 sets',
            'Cool-down: 10 minutes Savasana'
          ]
        );
      case 6:
        return (
          'Advanced Stretching',
          [
            'Warm-up: 5 minutes dynamic stretching',
            'Standing split: 3 sets x 20 seconds each leg',
            'Dancer\'s pose: 3 sets x 20 seconds each leg',
            'Wheel pose (or bridge if wheel is too advanced): 3 sets x 15 seconds',
            'Frog pose: 3 sets x 30 seconds',
            'Cool-down: 5 minutes gentle yoga'
          ]
        );
      case 7:
        return (
          'Rest & Recovery',
          [
            'Gentle full-body stretch routine',
            'Self-massage or foam rolling',
            'Mindfulness or meditation practice',
            'Review progress and set goals for the next week'
          ]
        );
      default:
        return ('Rest', ['Error: Invalid day']);
    }
  }
}
