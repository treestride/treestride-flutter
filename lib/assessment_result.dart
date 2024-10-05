import 'package:flutter/material.dart';

class AssessmentResults extends StatelessWidget {
  final List<String> answers;
  final VoidCallback onReassess;

  const AssessmentResults(
      {Key? key, required this.answers, required this.onReassess})
      : super(key: key);

  List<String> _getRecommendedExercises() {
    // This is a simple logic for demonstration. You should implement more sophisticated logic based on the answers.
    List<String> recommendations = [];

    if (answers[0] == 'Rarely' || answers[0] == '1-2 times a week') {
      recommendations
          .add('Start with 30 minutes of brisk walking 3 times a week');
    }

    if (answers[1] == 'Lose weight') {
      recommendations
          .add('Incorporate 20 minutes of HIIT workouts 2-3 times a week');
    } else if (answers[1] == 'Build muscle') {
      recommendations.add('Add strength training exercises 3 times a week');
    }

    if (answers[2] == 'Beginner') {
      recommendations
          .add('Try bodyweight exercises like push-ups, squats, and lunges');
    }

    if (answers[3] == 'Yes') {
      recommendations.add(
          'Consult with a physician or physical therapist for tailored exercises');
    }

    if (answers[4] == 'Yoga/Pilates') {
      recommendations.add('Include 2-3 yoga or Pilates sessions per week');
    }

    return recommendations;
  }

  @override
  Widget build(BuildContext context) {
    List<String> recommendedExercises = _getRecommendedExercises();

    return Column(
      children: [
        const Text(
          'Assessment Results',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        const Text(
          'Based on your answers, we recommend:',
          style: TextStyle(fontSize: 18),
        ),
        const SizedBox(height: 20),
        ListView.builder(
          shrinkWrap: true,
          itemCount: recommendedExercises.length,
          itemBuilder: (context, index) {
            return ListTile(
              leading: const Icon(Icons.fitness_center),
              title: Text(recommendedExercises[index]),
            );
          },
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: onReassess,
          child: const Text('Take Assessment Again'),
        ),
      ],
    );
  }
}
