import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BMICalculator extends StatefulWidget {
  const BMICalculator({super.key});

  @override
  BMICalculatorState createState() => BMICalculatorState();
}

class BMICalculatorState extends State<BMICalculator> {
  final _formKey = GlobalKey<FormState>();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _ageController = TextEditingController();
  String _gender = 'Male';
  double? _bmi;
  String _bmiCategory = '';

  @override
  void initState() {
    super.initState();
    _loadBMIData();
  }

  Future<void> _loadBMIData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _heightController.text = prefs.getString('height') ?? '';
      _weightController.text = prefs.getString('weight') ?? '';
      _ageController.text = prefs.getString('age') ?? '';
      _gender = prefs.getString('gender') ?? 'Male';
      _bmi = prefs.getDouble('bmi');
      _bmiCategory = prefs.getString('bmiCategory') ?? '';
    });
  }

  Future<void> _saveBMIData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('height', _heightController.text);
    await prefs.setString('weight', _weightController.text);
    await prefs.setString('age', _ageController.text);
    await prefs.setString('gender', _gender);
    await prefs.setDouble('bmi', _bmi!);
    await prefs.setString('bmiCategory', _bmiCategory);
  }

  void _calculateBMI() {
    if (_formKey.currentState!.validate()) {
      final height =
          double.parse(_heightController.text) / 100; // convert cm to m
      final weight = double.parse(_weightController.text);
      final age = int.parse(_ageController.text);

      setState(() {
        _bmi = weight / (height * height);

        // Adjust BMI based on age and gender
        if (age >= 18) {
          if (_gender == 'Male') {
            _bmi = _bmi! * 1.0; // No adjustment for adult males
          } else {
            _bmi = _bmi! * 0.95; // Slight adjustment for adult females
          }
        } else {
          // For children and teens, use age-specific BMI percentiles
          // This is a simplified adjustment and should be replaced with more accurate calculations
          _bmi = _bmi! * (0.8 + (age / 100));
        }

        if (_bmi! < 18.5) {
          _bmiCategory = 'Underweight';
        } else if (_bmi! < 25) {
          _bmiCategory = 'Normal weight';
        } else if (_bmi! < 30) {
          _bmiCategory = 'Overweight';
        } else {
          _bmiCategory = 'Obese';
        }
      });

      _saveBMIData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
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
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'BMI CALCULATOR',
              style: TextStyle(
                fontSize: 24,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildInputField(_heightController, 'Height (cm)'),
            const SizedBox(height: 16),
            _buildInputField(_weightController, 'Weight (kg)'),
            const SizedBox(height: 16),
            _buildInputField(_ageController, 'Age'),
            const SizedBox(height: 16),
            _buildGenderSelector(),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _calculateBMI,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF08DAD6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'CALCULATE BMI',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                ),
              ),
            ),
            if (_bmi != null) ...[
              const SizedBox(height: 24),
              _buildResultCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      cursorColor: const Color(0xFF08DAD6),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        floatingLabelStyle: const TextStyle(color: Color(0xFF08DAD6)),
        fillColor: const Color(0xFFEFEFEF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF08DAD6), width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF08DAD6), width: 2),
        ),
      ),
      keyboardType: TextInputType.number,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter a value';
        }
        return null;
      },
    );
  }

  Widget _buildGenderSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEFEF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _gender,
          isExpanded: true,
          items: ['Male', 'Female']
              .map((String value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  ))
              .toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                _gender = newValue;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    Color categoryColor;
    switch (_bmiCategory) {
      case 'Underweight':
        categoryColor = Colors.orange;
        break;
      case 'Normal weight':
        categoryColor = Colors.green;
        break;
      case 'Overweight':
        categoryColor = Colors.yellow.shade700;
        break;
      case 'Obese':
        categoryColor = Colors.red;
        break;
      default:
        categoryColor = Colors.blue.shade600;
    }

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
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'YOUR BMI',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _bmi!.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 18,
                color: Colors.blue.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: categoryColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _bmiCategory.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _ageController.dispose();
    super.dispose();
  }
}