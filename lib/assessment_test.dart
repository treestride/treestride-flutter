import 'package:flutter/material.dart';

class AssessmentTest extends StatefulWidget {
  final Function(List<String>) onComplete;

  const AssessmentTest({super.key, required this.onComplete});

  @override
  AssessmentTestState createState() => AssessmentTestState();
}

class AssessmentTestState extends State<AssessmentTest> {
  int _currentQuestionIndex = 0;
  final List<String> _answers = [];

  final List<Map<String, dynamic>> _questions = [
    {
      'question': 'How often do you exercise?',
      'options': [
        'Rarely',
        '1-2 times a week',
        '3-4 times a week',
        '5+ times a week'
      ],
    },
    {
      'question': 'What is your primary fitness goal?',
      'options': [
        'Lose weight',
        'Build muscle',
        'Improve cardiovascular health',
        'Increase flexibility'
      ],
    },
    {
      'question': 'How would you describe your current fitness level?',
      'options': ['Beginner', 'Intermediate', 'Advanced'],
    },
    {
      'question': 'Do you have any physical limitations or injuries?',
      'options': ['Yes', 'No'],
    },
    {
      'question': 'What type of exercises do you enjoy most?',
      'options': ['Cardio', 'Strength training', 'Yoga/Pilates', 'Team sports'],
    },
  ];

  void _answerQuestion(String answer) {
    setState(() {
      _answers.add(answer);
      if (_currentQuestionIndex < _questions.length - 1) {
        _currentQuestionIndex++;
      } else {
        widget.onComplete(_answers);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        Text(
          _questions[_currentQuestionIndex]['question'],
          style: const TextStyle(fontSize: 20),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        ..._questions[_currentQuestionIndex]['options'].map<Widget>((option) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: ElevatedButton(
              onPressed: () => _answerQuestion(option),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: Text(option),
            ),
          );
        }).toList(),
      ],
    );
  }
}
