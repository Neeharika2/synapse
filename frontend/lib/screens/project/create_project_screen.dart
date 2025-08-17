import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class CreateProjectScreen extends StatefulWidget {
  const CreateProjectScreen({super.key});

  @override
  State<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends State<CreateProjectScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _maxMembersController = TextEditingController(text: '5');
  final List<String> _selectedSkills = [];
  String _selectedVisibility = 'public';
  bool _isLoading = false;
  String? _errorMessage;

  final List<String> _suggestedSkills = [
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

  final List<String> _visibilityOptions = ['public', 'private', 'teaser'];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _maxMembersController.dispose();
    super.dispose();
  }

  Future<void> _createProject() async {
    // Validate fields
    if (_titleController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter a project title');
      return;
    }

    if (_descriptionController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter a project description');
      return;
    }

    if (_selectedSkills.isEmpty) {
      setState(
        () => _errorMessage = 'Please select at least one required skill',
      );
      return;
    }

    // Clear error message and show loading
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      final response = await ApiService.createProject(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        requiredSkills: _selectedSkills,
        maxMembers: int.tryParse(_maxMembersController.text) ?? 5,
        visibility: _selectedVisibility,
      );

      if (response['success']) {
        // Navigate back on success
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Project created successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context, true); // Return true to indicate success
      } else {
        setState(() {
          _errorMessage = response['error'] ?? 'Failed to create project';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Project'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'New Project Details',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Fill in the details below to create a new project',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 24),

            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red[700], fontSize: 14),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _errorMessage = null),
                      icon: const Icon(Icons.close, size: 16),
                      color: Colors.red[700],
                    ),
                  ],
                ),
              ),

            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Project Title *',
                hintText: 'Enter a clear, descriptive title',
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Description *',
                hintText:
                    'Describe your project goals, requirements, and expectations',
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _maxMembersController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Max Team Size',
                      hintText: '5',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedVisibility,
                    decoration: const InputDecoration(labelText: 'Visibility'),
                    items:
                        _visibilityOptions.map((visibility) {
                          return DropdownMenuItem(
                            value: visibility,
                            child: Text(
                              visibility[0].toUpperCase() +
                                  visibility.substring(1),
                            ),
                          );
                        }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedVisibility = value;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            const Text(
              'Required Skills *',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select skills that team members should have',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  _suggestedSkills.map((skill) {
                    return FilterChip(
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
                      selectedColor: const Color(0xFF6366F1).withOpacity(0.2),
                      checkmarkColor: const Color(0xFF6366F1),
                    );
                  }).toList(),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createProject,
                child:
                    _isLoading
                        ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.white,
                          ),
                        )
                        : const Text('Create Project'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
