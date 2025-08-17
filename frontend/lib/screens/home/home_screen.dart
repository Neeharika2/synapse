import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

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
  List<dynamic> _myTeams = []; // Teams I created
  List<dynamic> _joinedTeams = []; // Teams I joined but didn't create
  bool _isLoading = false;
  String? _errorMessage;
  late TabController _teamTabController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    _teamTabController = TabController(length: 2, vsync: this);
    _loadProjects();
    _loadMyProjects();
    _loadTeams();
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

  Future<void> _loadTeams() async {
    try {
      // Load teams I created
      final myTeamsResponse = await ApiService.getProjects(status: 'my_projects');
      if (myTeamsResponse['success']) {
        setState(() {
          _myTeams = myTeamsResponse['data'] ?? [];
        });
      }

      // Load teams I joined (but didn't create)
      final joinedTeamsResponse = await ApiService.getProjects(status: 'joined_projects');
      if (joinedTeamsResponse['success']) {
        setState(() {
          _joinedTeams = joinedTeamsResponse['data'] ?? [];
        });
      }
    } catch (e) {
      print('Failed to load teams: $e');
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
          _buildTeamsTab(),
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
          _currentIndex == 0 || _currentIndex == 2
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
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
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
                        return _buildProjectCard(
                          project['title'] ?? 'Untitled Project',
                          project['description'] ?? 'No description',
                          List<String>.from(project['required_skills'] ?? []),
                          _formatDate(project['created_at']),
                          '${project['current_members']}/${project['max_members']} members',
                        );
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

  Widget _buildTeamsTab() {
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
                const Text(
                  'Team Dashboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TabBar(
                  controller: _teamTabController,
                  indicatorColor: Colors.white,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  tabs: const [
                    Tab(text: 'My Teams'),
                    Tab(text: 'Joined Teams'),
                  ],
                ),
              ],
            ),
          ),

          // Teams content
          Expanded(
            child: TabBarView(
              controller: _teamTabController,
              children: [
                _buildMyTeamsContent(),
                _buildJoinedTeamsContent(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyTeamsContent() {
    if (_myTeams.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_work, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('No teams created yet'),
            const SizedBox(height: 8),
            const Text(
              'Create a project to start a new team',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showPostIdeaDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create Team'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTeams,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _myTeams.length,
        itemBuilder: (context, index) {
          final team = _myTeams[index];
          return _buildTeamCard(
            team,
            isCreator: true,
            onTap: () => _navigateToTeamDetails(team['id']),
          );
        },
      ),
    );
  }

  Widget _buildTeamCard(
    Map<String, dynamic> team, {
    required bool isCreator,
    required VoidCallback onTap,
  }) {
    final memberCount = '${team['current_members']}/${team['max_members']}';
    final status = team['status'] ?? 'open';
    final statusColor = _getStatusColor(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      team['title'] ?? 'Untitled Project',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                team['description'] ?? 'No description',
                style: const TextStyle(color: Colors.grey),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  // Members indicator
                  Row(
                    children: [
                      const Icon(Icons.people, size: 16, color: Colors.blue),
                      const SizedBox(width: 4),
                      Text(memberCount, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  const SizedBox(width: 16),

                  // Created date
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(team['created_at']),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Action button
                  isCreator
                      ? const Chip(
                        label: Text('Owner'),
                        backgroundColor: Color(0xFFE0F2F1),
                        labelStyle: TextStyle(color: Colors.teal, fontSize: 12),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      )
                      : const Chip(
                        label: Text('Member'),
                        backgroundColor: Color(0xFFE8EAF6),
                        labelStyle: TextStyle(
                          color: Colors.indigo,
                          fontSize: 12,
                        ),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToTeamDetails(String projectId) {
    Navigator.pushNamed(context, '/project', arguments: projectId);
  }

  Widget _buildProjectCard(
    String title,
    String description,
    List<String> skills,
    String timeAgo,
    String members,
  ) {
    // Find the project in the list
    final project = _projects.firstWhere(
      (p) => p['title'] == title,
      orElse: () => {'id': '', 'creator_id': ''},
    );
    
    // Check if current user is the creator
    final currentUserId = Provider.of<AuthProvider>(context, listen: false).user?['id']?.toString();
    final isCreator = project['creator_id']?.toString() == currentUserId;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ),
                Icon(Icons.bookmark_outline, color: Colors.grey[400]),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(color: Color(0xFF6B7280), height: 1.4),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children:
                  skills
                      .map(
                        (skill) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            skill,
                            style: const TextStyle(
                              color: Color(0xFF6366F1),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      )
                      .toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.group_outlined, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  members,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const Spacer(),
                Text(
                  timeAgo,
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                const SizedBox(width: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Only show join button if not the creator
                    if (!isCreator)
                      OutlinedButton(
                        onPressed: () => _showJoinRequestDialog(project),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF6366F1),
                          side: const BorderSide(color: Color(0xFF6366F1)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text('Request to Join'),
                      ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(
                        context,
                        '/project',
                        arguments: project['id'],
                      ),
                      child: isCreator 
                        ? const Text('Manage') 
                        : const Text('View Details'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showJoinRequestDialog(Map<String, dynamic> project) {
    final messageController = TextEditingController();
    bool isLoading = false;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Join ${project['title']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Send a request to join this project. You can include a message to the project owner.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: messageController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Message (Optional)',
                  hintText: 'Describe why you want to join this project...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      setState(() => isLoading = true);
                      
                      try {
                        final response = await ApiService.joinProject(
                          project['id'].toString(),
                          message: messageController.text.trim(),
                        );
                        
                        Navigator.pop(context);
                        
                        if (response['success']) {
                          _showSnackBar(
                            'Join request sent successfully!',
                            Colors.green,
                          );
                          // reload sent requests if you track them
                        } else {
                          _showSnackBar(
                            response['error'] ?? 'Failed to send join request',
                            Colors.red,
                          );
                        }
                      } catch (e) {
                        Navigator.pop(context);
                        _showSnackBar('Error: $e', Colors.red);
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send Request'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyProjectCard(Map<String, dynamic> project) {
    String status = project['status'] ?? 'open';
    Color statusColor = _getStatusColor(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    project['title'] ?? 'Untitled Project',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              project['description'] ?? 'No description',
              style: const TextStyle(color: Color(0xFF6B7280), height: 1.4),
            ),
            const SizedBox(height: 12),

            // Show required skills for my projects too
            if (project['required_skills'] != null &&
                project['required_skills'].isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children:
                      (project['required_skills'] as List<dynamic>)
                          .map(
                            (skill) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                skill.toString(),
                                style: const TextStyle(
                                  color: Color(0xFF6366F1),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                ),
              ),

            Row(
              children: [
                Icon(Icons.group_outlined, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${project['current_members']}/${project['max_members']} members',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const Spacer(),
                Text(
                  _formatDate(project['created_at']),
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                const SizedBox(width: 12),

                // Show different buttons based on user role
                _buildProjectActionButton(project),
              ],
            ),
          ],
        ),
      ),
    );
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
        onPressed: () => Navigator.pushNamed(context, '/project'),
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

  Widget _buildJoinedTeamsContent() {
    if (_joinedTeams.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('No joined teams yet'),
            const SizedBox(height: 8),
            const Text(
              'Join a project to become part of a team',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTeams,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _joinedTeams.length,
        itemBuilder: (context, index) {
          final team = _joinedTeams[index];
          return _buildTeamCard(
            team,
            isCreator: false,
            onTap: () => _navigateToTeamDetails(team['id']),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _teamTabController.dispose();
    super.dispose();
  }
}
