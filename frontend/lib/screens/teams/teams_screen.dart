import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/project_provider.dart';
import '../../models/project_model.dart';
import '../../services/api_service.dart';

class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  List<Project> myProjects = [];
  List<Project> joinedProjects = [];
  List<JoinRequest> pendingRequests = [];
  bool _isLoading = true;
  bool _hasRequests = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTeamsData();
  }

  Future<void> _loadTeamsData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?['id']?.toString();

      if (userId == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Load user's created projects
      final myProjectsResponse = await ApiService.getCreatedProjects();

      // Load projects the user has joined
      final joinedProjectsResponse = await ApiService.getJoinedProjects();

      // Check for pending requests in user's created projects
      List<JoinRequest> allRequests = [];
      for (var project in myProjectsResponse['projects']) {
        if (project['pendingRequests'] != null &&
            project['pendingRequests'].isNotEmpty) {
          for (var request in project['pendingRequests']) {
            allRequests.add(JoinRequest.fromJson(request));
          }
        }
      }

      setState(() {
        myProjects =
            myProjectsResponse['projects']
                .map<Project>((project) => Project.fromJson(project))
                .toList();
        joinedProjects =
            joinedProjectsResponse['projects']
                .map<Project>((project) => Project.fromJson(project))
                .toList();
        pendingRequests = allRequests;
        _hasRequests = pendingRequests.isNotEmpty;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load teams data: ${e.toString()}'),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teams'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_hasRequests ? 'Requests' : 'My Teams'),
                  if (_hasRequests) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${pendingRequests.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Joined Teams'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildMyTeamsTab(), _buildJoinedTeamsTab()],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to create project/team screen
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildMyTeamsTab() {
    if (_hasRequests) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Join Requests Section
            const Text(
              'Join Requests',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (pendingRequests.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No pending join requests'),
              )
            else
              ...pendingRequests.map(
                (request) => _buildJoinRequestCard(request),
              ),

            const SizedBox(height: 24),

            // My Projects Section
            const Text(
              'My Projects',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...myProjects.map((project) => _buildProjectCard(project, true)),
          ],
        ),
      );
    } else {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: myProjects.length,
        itemBuilder:
            (context, index) => _buildProjectCard(myProjects[index], true),
      );
    }
  }

  Widget _buildJoinedTeamsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: joinedProjects.length,
      itemBuilder:
          (context, index) => _buildProjectCard(joinedProjects[index], false),
    );
  }

  Widget _buildProjectCard(Project project, bool isCreator) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF6366F1),
          child: Text(project.title[0].toUpperCase()),
        ),
        title: Text(project.title),
        subtitle: Text('${project.members.length} members'),
        trailing: const Icon(Icons.arrow_forward),
        onTap: () {
          Navigator.of(
            context,
          ).pushNamed('/project-dashboard', arguments: project.id);
        },
      ),
    );
  }

  Widget _buildJoinRequestCard(JoinRequest request) {
    // Find which project this request belongs to
    final project = myProjects.firstWhere(
      (p) => p.pendingRequests.any((r) => r.id == request.id),
      orElse: () => myProjects.first, // fallback
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF6366F1),
                  child: Text(request.user.name[0].toUpperCase()),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.user.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Requested to join ${project.title}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (request.message != null && request.message!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(request.message!),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed:
                      () => _respondToRequest(project.id, request.id, false),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Decline'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed:
                      () => _respondToRequest(project.id, request.id, true),
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

  Future<void> _respondToRequest(
    String projectId,
    String requestId,
    bool accept,
  ) async {
    try {
      final response = await ApiService.respondToJoinRequest(
        projectId,
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

        // Refresh data
        _loadTeamsData();
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
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
