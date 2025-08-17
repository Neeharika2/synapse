import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/project_provider.dart';
import '../../models/project_model.dart';
import 'dart:convert';
import '../../services/api_service.dart';

class ProjectDashboardScreen extends StatefulWidget {
  const ProjectDashboardScreen({super.key});

  @override
  State<ProjectDashboardScreen> createState() => _ProjectDashboardScreenState();
}

class _ProjectDashboardScreenState extends State<ProjectDashboardScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  Project? _project;
  bool _isLoading = true;
  bool _isMember = false;

  @override
  void initState() {
    super.initState();
    // Adding a fifth tab for Requests
    _tabController = TabController(length: 5, vsync: this);
    // We'll load the project data once the widget is fully built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProjectData();
    });
  }

  Future<void> _loadProjectData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final projectProvider = Provider.of<ProjectProvider>(
      context,
      listen: false,
    );
    final String? projectId =
        ModalRoute.of(context)?.settings.arguments as String?;

    if (projectId == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final success = await projectProvider.getProjectDetails(projectId);
      final userId = authProvider.user?['id']?.toString();

      setState(() {
        _isLoading = false;
      });

      if (success) {
        final project = projectProvider.currentProject;
        setState(() {
          _project = project;
          _isMember =
              userId != null &&
              project != null &&
              (project.creator.id == userId ||
                  project.members.any((member) => member.id == userId));
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(projectProvider.errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load project: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_project == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Project Details')),
        body: const Center(child: Text('Project not found')),
      );
    }

    if (!_isMember) {
      return Scaffold(
        appBar: AppBar(title: Text(_project!.title)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Access Restricted',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'You need to join this project to access the team dashboard.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              Consumer<ProjectProvider>(
                builder: (context, projectProvider, child) {
                  return ElevatedButton(
                    onPressed:
                        projectProvider.isLoading
                            ? null
                            : () async {
                              final success = await projectProvider.joinProject(
                                _project!.id,
                              );
                              if (success) {
                                setState(() {
                                  _isMember = true;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Successfully joined the project!',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(projectProvider.errorMessage),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                    child:
                        projectProvider.isLoading
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Text('Join Project'),
                  );
                },
              ),
            ],
          ),
        ),
      );
    }

    // For the project dashboard when user is a member
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_project!.title, style: const TextStyle(fontSize: 18)),
            Text(
              'Team Dashboard',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              // TODO: Show project settings
            },
            icon: const Icon(Icons.more_vert),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(icon: Icon(Icons.chat_outlined), text: 'Chat'),
            const Tab(icon: Icon(Icons.task_outlined), text: 'Tasks'),
            const Tab(icon: Icon(Icons.folder_outlined), text: 'Files'),
            const Tab(
              icon: Icon(Icons.calendar_today_outlined),
              text: 'Schedule',
            ),
            // New tab for requests - only visible to creator
            if (_isCreator())
              Tab(
                icon: Stack(
                  children: [
                    const Icon(Icons.person_add_outlined),
                    if (_project!.pendingRequests.isNotEmpty)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 14,
                            minHeight: 14,
                          ),
                          child: Text(
                            '${_project!.pendingRequests.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                text: 'Requests',
              ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildChatTab(),
          _buildTasksTab(),
          _buildFilesTab(),
          _buildScheduleTab(),
          if (_isCreator()) _buildRequestsTab(),
        ],
      ),
    );
  }

  bool _isCreator() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return _project != null &&
        authProvider.user != null &&
        _project!.creator.id == authProvider.user!['id'].toString();
  }

  Widget _buildRequestsTab() {
    if (_project == null || _project!.pendingRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('No pending join requests'),
            const SizedBox(height: 8),
            const Text(
              'When someone requests to join your project, you\'ll see it here',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _project!.pendingRequests.length,
      itemBuilder: (context, index) {
        final request = _project!.pendingRequests[index];
        return _buildJoinRequestCard(request);
      },
    );
  }

  Widget _buildJoinRequestCard(JoinRequest request) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF6366F1),
                  child: Text(
                    request.user.name.isNotEmpty
                        ? request.user.name[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.user.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Requested ${_formatDate(request.requestedAt.toIso8601String())}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (request.message != null && request.message!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(request.message!),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => _respondToJoinRequest(request.id, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                  child: const Text('Decline'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => _respondToJoinRequest(request.id, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: const Text('Accept'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _respondToJoinRequest(String requestId, bool accept) async {
    setState(() => _isLoading = true);

    try {
      final response = await ApiService.respondToJoinRequest(
        _project!.id,
        requestId,
        accept,
      );

      if (response['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              accept ? 'User added to the project' : 'Request declined',
            ),
            backgroundColor: accept ? Colors.green : Colors.grey,
          ),
        );

        // Refresh project data to update member list and pending requests
        _loadProjectData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['error'] ?? 'Failed to process request'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget _buildChatTab() {
    return Column(
      children: [
        // Team Members Header
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFFF9FAFB),
          child: Row(
            children: [
              const Text(
                'Team Members:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              _buildAvatarStack(),
              const Spacer(),
              TextButton(onPressed: () {}, child: const Text('Invite')),
            ],
          ),
        ),

        // Chat Messages
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildChatMessage(
                'John Doe',
                'Hey team! I\'ve started working on the UI wireframes. Will share them by EOD.',
                '10:30 AM',
                true,
              ),
              _buildChatMessage(
                'Sarah Wilson',
                'Great! I\'m working on the backend API structure. Should have the endpoints ready by tomorrow.',
                '10:35 AM',
                false,
              ),
              _buildChatMessage(
                'Mike Chen',
                'I\'ll start on the AI model integration once the backend is ready. Looking forward to seeing the wireframes!',
                '10:40 AM',
                false,
              ),
              _buildChatMessage(
                'You',
                'Perfect! Let me know if you need any help with the Flutter implementation.',
                '10:45 AM',
                true,
              ),
            ],
          ),
        ),

        // Message Input
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey[200]!)),
          ),
          child: Row(
            children: [
              const Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FloatingActionButton(
                mini: true,
                onPressed: () {},
                child: const Icon(Icons.send, size: 20),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTasksTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Progress Header
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Project Progress',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: 0.65,
                  backgroundColor: Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF6366F1),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '65% Complete • 8 of 12 tasks done',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Task Sections
        _buildTaskSection('To Do', [
          _buildTaskItem('Set up project repository', 'Mike Chen', false),
          _buildTaskItem('Create database schema', 'Sarah Wilson', false),
        ]),
        _buildTaskSection('In Progress', [
          _buildTaskItem('Design UI wireframes', 'John Doe', false),
          _buildTaskItem('Research AI APIs', 'You', false),
        ]),
        _buildTaskSection('Completed', [
          _buildTaskItem('Project planning meeting', 'Team', true),
          _buildTaskItem('Define project requirements', 'Team', true),
          _buildTaskItem('Technology stack finalization', 'Team', true),
        ]),
      ],
    );
  }

  Widget _buildFilesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildFileItem(
          'Project_Requirements.pdf',
          '2.3 MB',
          Icons.picture_as_pdf,
          Colors.red,
        ),
        _buildFileItem(
          'UI_Wireframes.fig',
          '15.7 MB',
          Icons.design_services,
          Colors.purple,
        ),
        _buildFileItem(
          'API_Documentation.docx',
          '1.8 MB',
          Icons.description,
          Colors.blue,
        ),
        _buildFileItem(
          'Database_Schema.sql',
          '0.5 MB',
          Icons.storage,
          Colors.orange,
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.add),
          label: const Text('Upload File'),
        ),
      ],
    );
  }

  Widget _buildScheduleTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Upcoming Meetings',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildMeetingItem(
                  'Sprint Planning',
                  'Tomorrow, 3:00 PM',
                  'Google Meet',
                ),
                _buildMeetingItem('Design Review', 'Friday, 2:00 PM', 'Figma'),
                _buildMeetingItem(
                  'Code Review',
                  'Next Monday, 4:00 PM',
                  'Google Meet',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.add),
          label: const Text('Schedule Meeting'),
        ),
      ],
    );
  }

  Widget _buildAvatarStack() {
    if (_project == null || _project!.members.isEmpty) {
      return const CircleAvatar(
        radius: 16,
        backgroundColor: Color(0xFF6366F1),
        child: Icon(Icons.person, color: Colors.white, size: 16),
      );
    }

    final membersToShow = _project!.members.take(3).toList();

    return Stack(
      children: [
        for (int i = 0; i < membersToShow.length; i++)
          Positioned(
            left: i * 20.0,
            child: CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF6366F1),
              child: Text(
                membersToShow[i].name.isNotEmpty
                    ? membersToShow[i].name[0].toUpperCase()
                    : 'U',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        if (_project!.members.length > 3)
          Positioned(
            left: 60.0,
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[300],
              child: Text(
                '+${_project!.members.length - 3}',
                style: TextStyle(color: Colors.grey[700], fontSize: 12),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildChatMessage(
    String sender,
    String message,
    String time,
    bool isMe,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF6366F1),
              child: Text(
                sender[0],
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isMe ? const Color(0xFF6366F1) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    message,
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$sender • $time',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF6366F1),
              child: Text(
                sender[0],
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTaskSection(String title, List<Widget> tasks) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...tasks,
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTaskItem(String title, String assignee, bool isCompleted) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCompleted ? Colors.green[50] : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCompleted ? Colors.green[200]! : Colors.grey[200]!,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isCompleted ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Assigned to $assignee',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileItem(String name, String size, IconData icon, Color color) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.2),
        child: Icon(icon, color: color),
      ),
      title: Text(name),
      subtitle: Text(size),
      trailing: IconButton(onPressed: () {}, icon: const Icon(Icons.download)),
    );
  }

  Widget _buildMeetingItem(String title, String time, String platform) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.event, color: Color(0xFF6366F1)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '$time • $platform',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          TextButton(onPressed: () {}, child: const Text('Join')),
        ],
      ),
    );
  }

  String _formatDate(String isoDateString) {
    try {
      final dateTime = DateTime.parse(isoDateString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return isoDateString; // Fallback in case of error
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
