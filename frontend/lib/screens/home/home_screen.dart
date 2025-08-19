import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../teams/teams_screen.dart';

class HomeScreen extends StatefulWidget {
  final int initialTab;
  const HomeScreen({super.key, this.initialTab = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late int _currentIndex;
  final _searchController = TextEditingController();
  List<dynamic> _projects = [];
  List<dynamic> _myProjects = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    _loadProjects();
    _loadMyProjects();
  }

  Future<void> _loadProjects() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiService.getProjects();
      if (response['success']) {
        setState(() {
          _projects = response['data'] ?? [];
        });
      } else {
        setState(() {
          _errorMessage = response['error'];
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load projects: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMyProjects() async {
    try {
      final response = await ApiService.getProjects(status: 'my_projects');
      if (response['success']) {
        setState(() {
          _myProjects = response['data'] ?? [];
        });
      }
    } catch (e) {
      print('Failed to load my projects: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildDiscoveryTab(),
          _buildMyProjectsTab(),
          const TeamsScreen(), // Using TeamsScreen component
          _buildProfileTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF6366F1),
        unselectedItemColor: const Color(0xFF6B7280),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            activeIcon: Icon(Icons.explore),
            label: 'Discover',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.work_outline),
            activeIcon: Icon(Icons.work),
            label: 'My Projects',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group_outlined),
            activeIcon: Icon(Icons.group),
            label: 'Teams',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
      floatingActionButton:
          _currentIndex == 0 || _currentIndex == 1
              ? FloatingActionButton(
                onPressed: _showPostIdeaDialog,
                backgroundColor: const Color(0xFF6366F1),
                child: const Icon(Icons.add, color: Colors.white),
              )
              : null,
    );
  }

  Widget _buildDiscoveryTab() {
    final authProvider = Provider.of<AuthProvider>(context, listen: true);
    final displayName = authProvider.user?['name'] ?? 'Student';

    return SafeArea(
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFF6366F1),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person, color: Color(0xFF6366F1)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Welcome back!',
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                          Text(
                            displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(
                        Icons.notifications_outlined,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search projects, skills, or students...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onSubmitted: (value) => _searchProjects(value),
                ),
              ],
            ),
          ),

          // Project Cards
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(_errorMessage!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadProjects,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _projects.length,
                      itemBuilder: (context, index) {
                        final project = _projects[index];
                        return _buildProjectCard(project);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyProjectsTab() {
    return SafeArea(
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFF6366F1),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'My Projects',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _loadMyProjects,
                  icon: const Icon(Icons.refresh, color: Colors.white),
                ),
              ],
            ),
          ),

          // My Projects List
          Expanded(
            child:
                _myProjects.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.work_outline,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No projects yet',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Start by posting your first project idea!',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _showPostIdeaDialog,
                            child: const Text('Post Project'),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _myProjects.length,
                      itemBuilder: (context, index) {
                        final project = _myProjects[index];
                        return _buildMyProjectCard(project);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Profile Header
                const CircleAvatar(
                  radius: 50,
                  backgroundColor: Color(0xFF6366F1),
                  child: Icon(Icons.person, color: Colors.white, size: 50),
                ),
                const SizedBox(height: 16),
                Text(
                  authProvider.user?['name'] ?? 'Student Name',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  authProvider.user?['email'] ?? 'student@email.com',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 32),

                // Profile Stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatCard('Projects', '5'),
                    _buildStatCard('Completed', '3'),
                    _buildStatCard('Rating', '4.8'),
                  ],
                ),
                const SizedBox(height: 32),

                // Remove Team Dashboard Button from profile tab since it's now in bottom nav

                // Profile Actions
                _buildProfileAction(
                  icon: Icons.edit,
                  title: 'Edit Profile',
                  subtitle: 'Update your information',
                  onTap: () => Navigator.pushNamed(context, '/profile-setup'),
                ),
                _buildProfileAction(
                  icon: Icons.school,
                  title: 'Academic Info',
                  subtitle: 'Branch, year, skills',
                  onTap: () {},
                ),
                _buildProfileAction(
                  icon: Icons.work,
                  title: 'My Portfolio',
                  subtitle: 'View completed projects',
                  onTap: () {},
                ),
                _buildProfileAction(
                  icon: Icons.settings,
                  title: 'Settings',
                  subtitle: 'App preferences',
                  onTap: () {},
                ),
                _buildProfileAction(
                  icon: Icons.help_outline,
                  title: 'Help & Support',
                  subtitle: 'Get help and feedback',
                  onTap: () {},
                ),
                const SizedBox(height: 32),

                // Logout Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await authProvider.logout();
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text(
                      'Logout',
                      style: TextStyle(color: Colors.red),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF6366F1),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildProfileAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF6366F1).withOpacity(0.1),
          child: Icon(icon, color: const Color(0xFF6366F1)),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  Future<void> _searchProjects(String query) async {
    if (query.isEmpty) {
      _loadProjects();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiService.getProjects(search: query);
      if (response['success']) {
        setState(() {
          _projects = response['data'] ?? [];
        });
      } else {
        setState(() {
          _errorMessage = response['error'];
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Search failed: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Recently';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 7) {
        return '${difference.inDays ~/ 7} weeks ago';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} days ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hours ago';
      } else {
        return 'Recently';
      }
    } catch (e) {
      return 'Recently';
    }
  }

  void _showPostIdeaDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final maxMembersController = TextEditingController(text: '5');
    final List<String> selectedSkills = [];
    bool isLoading = false;
    String selectedVisibility = 'public';

    final List<String> suggestedSkills = [
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setModalState) => Container(
                  padding: EdgeInsets.only(
                    top: 20,
                    left: 20,
                    right: 20,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Center(
                          child: Text(
                            'Post New Project',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        TextField(
                          controller: titleController,
                          decoration: const InputDecoration(
                            labelText: 'Project Title *',
                            hintText: 'What\'s your project idea?',
                          ),
                        ),
                        const SizedBox(height: 16),

                        TextField(
                          controller: descriptionController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Description *',
                            hintText: 'Describe your project in detail...',
                          ),
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: maxMembersController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Max Members',
                                  hintText: '5',
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedVisibility,
                                decoration: const InputDecoration(
                                  labelText: 'Visibility',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'public',
                                    child: Text('Public'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'private',
                                    child: Text('Private'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'teaser',
                                    child: Text('Teaser'),
                                  ),
                                ],
                                onChanged: (value) {
                                  setModalState(() {
                                    selectedVisibility = value!;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        const Text(
                          'Required Skills *',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              suggestedSkills
                                  .map(
                                    (skill) => FilterChip(
                                      label: Text(skill),
                                      selected: selectedSkills.contains(skill),
                                      onSelected: (selected) {
                                        setModalState(() {
                                          if (selected) {
                                            selectedSkills.add(skill);
                                          } else {
                                            selectedSkills.remove(skill);
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
                        const SizedBox(height: 20),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed:
                                isLoading
                                    ? null
                                    : () async {
                                      // Validation
                                      if (titleController.text.trim().isEmpty) {
                                        _showSnackBar(
                                          'Please enter a project title',
                                          Colors.red,
                                        );
                                        return;
                                      }
                                      if (descriptionController.text
                                          .trim()
                                          .isEmpty) {
                                        _showSnackBar(
                                          'Please enter a project description',
                                          Colors.red,
                                        );
                                        return;
                                      }
                                      if (selectedSkills.isEmpty) {
                                        _showSnackBar(
                                          'Please select at least one skill',
                                          Colors.red,
                                        );
                                        return;
                                      }

                                      setModalState(() => isLoading = true);

                                      try {
                                        final response =
                                            await ApiService.createProject(
                                              title:
                                                  titleController.text.trim(),
                                              description:
                                                  descriptionController.text
                                                      .trim(),
                                              requiredSkills: selectedSkills,
                                              maxMembers:
                                                  int.tryParse(
                                                    maxMembersController.text,
                                                  ) ??
                                                  5,
                                              visibility: selectedVisibility,
                                            );

                                        if (response['success']) {
                                          Navigator.pop(context);
                                          _showSnackBar(
                                            'Project created successfully!',
                                            Colors.green,
                                          );
                                          _loadProjects(); // Refresh projects list
                                          _loadMyProjects(); // Refresh my projects list
                                        } else {
                                          _showSnackBar(
                                            response['error'] ??
                                                'Failed to create project',
                                            Colors.red,
                                          );
                                        }
                                      } catch (e) {
                                        _showSnackBar(
                                          'Network error: $e',
                                          Colors.red,
                                        );
                                      } finally {
                                        setModalState(() => isLoading = false);
                                      }
                                    },
                            child:
                                isLoading
                                    ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                    : const Text('Create Project'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return Colors.green;
      case 'closed':
        return Colors.red;
      case 'in progress':
        return Colors.orange;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Widget _buildProjectActionButton(Map<String, dynamic> project) {
    // Determine user's role in this project
    final currentUserId =
        Provider.of<AuthProvider>(
          context,
          listen: false,
        ).user?['id']?.toString();
    final creatorId = project['creator_id']?.toString();
    final isCreator = currentUserId == creatorId;

    if (isCreator) {
      return TextButton(
        onPressed: () {
          try {
            Navigator.pushNamed(
              context,
              '/project',
              arguments: project['id'].toString(),
            );
          } catch (e) {
            print('Navigation error: $e');
            _showSnackBar('Navigation error: $e', Colors.red);
          }
        },
        child: const Text('Manage'),
      );
    } else {
      return TextButton(
        onPressed: () => _showLeaveProjectDialog(project),
        style: TextButton.styleFrom(foregroundColor: Colors.red),
        child: const Text('Leave'),
      );
    }
  }

  void _showLeaveProjectDialog(Map<String, dynamic> project) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Leave Project'),
            content: Text(
              'Are you sure you want to leave "${project['title']}"? You will need to request to rejoin if you change your mind.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _leaveProject(project['id'].toString());
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Leave'),
              ),
            ],
          ),
    );
  }

  Future<void> _leaveProject(String projectId) async {
    try {
      // Show loading indicator
      setState(() => _isLoading = true);

      _showSnackBar('Leaving project...', Colors.blue);

      final response = await ApiService.leaveProject(projectId);

      if (response['success']) {
        _showSnackBar('Left project successfully', Colors.green);

        // Remove from my projects list locally
        setState(() {
          _myProjects.removeWhere(
            (project) => project['id'].toString() == projectId,
          );
        });
      } else {
        _showSnackBar(
          response['error'] ?? 'Failed to leave project',
          Colors.red,
        );
      }
    } catch (e) {
      _showSnackBar('Network error: $e', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildMyProjectCard(Map<String, dynamic> project) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        title: Text(project['title'] ?? 'Untitled Project'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(project['description'] ?? 'No description'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children:
                  (project['required_skills'] as List<dynamic>? ?? [])
                      .map(
                        (skill) => Chip(
                          label: Text(skill.toString()),
                          backgroundColor: const Color(0xFFF3F4F6),
                        ),
                      )
                      .toList(),
            ),
            const SizedBox(height: 8),
            Text(
              'Status: ${project['status'] ?? 'Unknown'}',
              style: TextStyle(
                color: _getStatusColor(project['status'] ?? ''),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Created: ${_formatDate(project['created_at'])}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: _buildProjectActionButton(project),
        onTap: () {
          try {
            Navigator.pushNamed(
              context,
              '/project',
              arguments: project['id'].toString(),
            );
          } catch (e) {
            print('Navigation error: $e');
            _showSnackBar('Navigation error: $e', Colors.red);
          }
        },
      ),
    );
  }

  Widget _buildProjectCard(Map<String, dynamic> project) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.user?['id']?.toString();
    final creatorId = project['creator_id']?.toString();
    final isCreator = currentUserId == creatorId;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        title: Text(project['title'] ?? 'Untitled Project'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(project['description'] ?? 'No description'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children:
                  (project['required_skills'] as List<dynamic>? ?? [])
                      .map(
                        (skill) => Chip(
                          label: Text(skill.toString()),
                          backgroundColor: const Color(0xFFF3F4F6),
                        ),
                      )
                      .toList(),
            ),
            const SizedBox(height: 8),
            Text(
              'Status: ${project['status'] ?? 'Unknown'}',
              style: TextStyle(
                color: _getStatusColor(project['status'] ?? ''),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Created: ${_formatDate(project['created_at'])}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            if (!isCreator)
              ElevatedButton(
                onPressed: () => _requestToJoinProject(project),
                child: const Text('Request to Join'),
              ),
          ],
        ),
        onTap: () {
          try {
            Navigator.pushNamed(
              context,
              '/project',
              arguments: project['id'].toString(),
            );
          } catch (e) {
            print('Navigation error: $e');
            _showSnackBar('Navigation error: $e', Colors.red);
          }
        },
      ),
    );
  }

  Future<void> _requestToJoinProject(Map<String, dynamic> project) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?['id']?.toString();

    if (userId == null) {
      _showSnackBar('Please log in to request to join a project.', Colors.red);
      return;
    }

    try {
      final response = await ApiService.joinProject(project['id'].toString());

      if (response['success']) {
        _showSnackBar(
          'Request to join "${project['title']}" sent successfully!',
          Colors.green,
        );
      } else {
        _showSnackBar(
          response['error'] ?? 'Failed to send request to join project',
          Colors.red,
        );
      }
    } catch (e) {
      _showSnackBar('Network error: $e', Colors.red);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
