import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  String _selectedBranch = '';
  String _selectedYear = '';
  final List<String> _selectedSkills = [];
  final _bioController = TextEditingController();
  bool _isLoading = false;

  final List<String> branches = [
    'Computer Science',
    'Information Technology',
    'Electronics',
    'Mechanical',
    'Civil',
    'Electrical',
    'Other',
  ];

  final List<String> years = ['1st Year', '2nd Year', '3rd Year', '4th Year'];

  final List<String> skills = [
    'Flutter/Mobile Dev',
    'React/Frontend',
    'Backend Development',
    'UI/UX Design',
    'Data Science',
    'Machine Learning',
    'Content Writing',
    'Digital Marketing',
    'Project Management',
    'Graphic Design',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Let\'s set up your profile to find the perfect team members!',
                style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 32),

              // Branch Selection
              const Text(
                'Branch/Stream',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  hintText: 'Select your branch',
                ),
                value: _selectedBranch.isEmpty ? null : _selectedBranch,
                items:
                    branches
                        .map(
                          (branch) => DropdownMenuItem(
                            value: branch,
                            child: Text(branch),
                          ),
                        )
                        .toList(),
                onChanged: (value) => setState(() => _selectedBranch = value!),
                validator:
                    (value) =>
                        value == null ? 'Please select your branch' : null,
              ),
              const SizedBox(height: 24),

              // Year Selection
              const Text(
                'Year of Study',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(hintText: 'Select your year'),
                value: _selectedYear.isEmpty ? null : _selectedYear,
                items:
                    years
                        .map(
                          (year) =>
                              DropdownMenuItem(value: year, child: Text(year)),
                        )
                        .toList(),
                onChanged: (value) => setState(() => _selectedYear = value!),
                validator:
                    (value) => value == null ? 'Please select your year' : null,
              ),
              const SizedBox(height: 24),

              // Skills Selection
              const Text(
                'Skills & Interests',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select skills you have or want to learn',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    skills
                        .map(
                          (skill) => FilterChip(
                            label: Text(skill),
                            selected: _selectedSkills.contains(skill),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedSkills.add(skill);
                                } else {
                                  _selectedSkills.remove(skill);
                                }
                              });
                            },
                            backgroundColor: const Color(0xFFF3F4F6),
                            selectedColor: const Color(
                              0xFF6366F1,
                            ).withOpacity(0.2),
                            checkmarkColor: const Color(0xFF6366F1),
                          ),
                        )
                        .toList(),
              ),
              const SizedBox(height: 24),

              // Bio
              const Text(
                'About You (Optional)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _bioController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText:
                      'Tell us about your interests, past projects, or what you\'re passionate about...',
                ),
              ),
              const SizedBox(height: 40),

              // Complete Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleComplete,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Complete Setup'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleComplete() {
    if (_formKey.currentState!.validate() && _selectedSkills.isNotEmpty) {
      // TODO: Save profile data to backend
      Navigator.pushReplacementNamed(context, '/home');
    } else if (_selectedSkills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one skill')),
      );
    }
  }

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }
}
