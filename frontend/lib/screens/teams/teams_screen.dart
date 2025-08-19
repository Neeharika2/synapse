import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
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
  List<JoinRequest> receivedRequests = [];
  List<JoinRequest> sentRequests = [];
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

      print('🔍 Loading teams data for user: $userId');

      if (userId == null) {
        print('❌ No user ID found');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Load user's created projects
      print('📤 Loading created projects...');
      final myProjectsResponse = await ApiService.getCreatedProjects();
      print('📥 Created projects response: $myProjectsResponse');

      // Load projects the user has joined
      print('📤 Loading joined projects...');
      final joinedProjectsResponse = await ApiService.getJoinedProjects();
      print('📥 Joined projects response: $joinedProjectsResponse');

      // Load received join requests (requests to join your projects)
      print('📤 Loading received requests...');
      final receivedRequestsResponse = await ApiService.getReceivedRequests();
      print('📥 Received requests response: $receivedRequestsResponse');

      // Load sent join requests (your requests to join other projects)
      print('📤 Loading sent requests...');
      final sentRequestsResponse = await ApiService.getSentRequests();
      print('📥 Sent requests response: $sentRequestsResponse');

      setState(() {
        // Process created projects
        if (myProjectsResponse['success'] &&
            myProjectsResponse['projects'] != null) {
          try {
            myProjects =
                (myProjectsResponse['projects'] as List)
                    .map<Project>((project) => Project.fromJson(project))
                    .toList();
            print('✅ Created projects loaded: ${myProjects.length}');
          } catch (e) {
            print('❌ Error parsing created projects: $e');
            myProjects = [];
          }
        } else {
          print(
            '❌ Failed to load created projects: ${myProjectsResponse['error']}',
          );
          myProjects = [];
          if (!myProjectsResponse['error'].toString().contains('connection')) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Failed to load created projects: ${myProjectsResponse['error']}',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        }

        // Process joined projects
        if (joinedProjectsResponse['success'] &&
            joinedProjectsResponse['projects'] != null) {
          try {
            joinedProjects =
                (joinedProjectsResponse['projects'] as List)
                    .map<Project>((project) => Project.fromJson(project))
                    .toList();
            print('✅ Joined projects loaded: ${joinedProjects.length}');
          } catch (e) {
            print('❌ Error parsing joined projects: $e');
            joinedProjects = [];
          }
        } else {
          print(
            '❌ Failed to load joined projects: ${joinedProjectsResponse['error']}',
          );
          joinedProjects = [];
        }

        // Process received requests
        if (receivedRequestsResponse['success'] &&
            receivedRequestsResponse['data'] != null) {
          try {
            final requestsData = receivedRequestsResponse['data'];
            print('🔍 Received requests data: $requestsData');

            if (requestsData is List) {
              receivedRequests =
                  requestsData
                      .map<JoinRequest>(
                        (request) => JoinRequest.fromJson(request),
                      )
                      .toList();
              print('✅ Received requests loaded: ${receivedRequests.length}');
            } else {
              print(
                '❌ Unexpected received requests data format: ${requestsData.runtimeType}',
              );
              receivedRequests = [];
            }
          } catch (e) {
            print('❌ Error parsing received requests: $e');
            receivedRequests = [];
          }
        } else {
          print(
            '❌ Failed to load received requests: ${receivedRequestsResponse['error']}',
          );
          receivedRequests = [];
        }

        // Process sent requests
        if (sentRequestsResponse['success'] &&
            sentRequestsResponse['data'] != null) {
          try {
            final requestsData = sentRequestsResponse['data'];
            print('🔍 Sent requests data: $requestsData');

            if (requestsData is List) {
              sentRequests =
                  requestsData
                      .map<JoinRequest>(
                        (request) => JoinRequest.fromJson(request),
                      )
                      .toList();
              print('✅ Sent requests loaded: ${sentRequests.length}');
            } else {
              print(
                '❌ Unexpected sent requests data format: ${requestsData.runtimeType}',
              );
              sentRequests = [];
            }
          } catch (e) {
            print('❌ Error parsing sent requests: $e');
            sentRequests = [];
          }
        } else {
          print(
            '❌ Failed to load sent requests: ${sentRequestsResponse['error']}',
          );
          sentRequests = [];
        }

        _hasRequests = receivedRequests.isNotEmpty || sentRequests.isNotEmpty;
        print(
          '🔍 Has requests: $_hasRequests (Received: ${receivedRequests.length}, Sent: ${sentRequests.length})',
        );
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading teams data: $e');
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
        actions: [
          IconButton(
            onPressed: () {
              print('🔄 Manual refresh triggered');
              _loadTeamsData();
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Requests'),
                  if (_hasRequests) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${receivedRequests.length + sentRequests.length}',
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
            const Tab(text: 'Teams'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildRequestsTab(), _buildTeamsTab()],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to create project/team screen
          Navigator.of(context).pushNamed('/create-project');
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildRequestsTab() {
    print(
      '🔍 Building requests tab - Has requests: $_hasRequests, Received: ${receivedRequests.length}, Sent: ${sentRequests.length}',
    );

    if (!_hasRequests) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mail_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No requests',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Text(
              'You don\'t have any sent or received requests',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            // Add debug information
            Text(
              'Debug: Received=${receivedRequests.length}, Sent=${sentRequests.length}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Debug header
          Container(
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Debug: Received=${receivedRequests.length}, Sent=${sentRequests.length}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),

          // Received Requests Section
          const Text(
            'Received Requests',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (receivedRequests.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 24.0),
              child: Text('No pending requests to join your projects'),
            )
          else
            ...receivedRequests.map(
              (request) => _buildJoinRequestCard(request, true),
            ),

          const SizedBox(height: 24),

          // Sent Requests Section
          const Text(
            'Sent Requests',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (sentRequests.isEmpty)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('You haven\'t sent any join requests'),
            )
          else
            ...sentRequests.map(
              (request) => _buildJoinRequestCard(request, false),
            ),
        ],
      ),
    );
  }

  Widget _buildTeamsTab() {
    final allProjects = [...myProjects, ...joinedProjects];

    if (allProjects.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_work, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No teams yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create or join a team to get started',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pushNamed('/create-project');
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Team'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // My Created Teams Section
        if (myProjects.isNotEmpty) ...[
          const Text(
            'My Teams',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...myProjects.map((project) => _buildProjectCard(project, true)),
          const SizedBox(height: 16),
        ],

        // Joined Teams Section
        if (joinedProjects.isNotEmpty) ...[
          const Text(
            'Joined Teams',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...joinedProjects.map((project) => _buildProjectCard(project, false)),
        ],
      ],
    );
  }

  Widget _buildProjectCard(Project project, bool isCreator) {
    try {
      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: const Color(0xFF6366F1),
            child: Text(
              project.title.isNotEmpty ? project.title[0].toUpperCase() : 'P',
            ),
          ),
          title: Text(
            project.title.isNotEmpty ? project.title : 'Untitled Project',
          ),
          subtitle: Text('${project.members.length} members'),
          trailing: const Icon(Icons.arrow_forward),
          onTap: () {
            try {
              Navigator.of(
                context,
              ).pushNamed('/project', arguments: project.id);
            } catch (e) {
              print('Navigation error: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Navigation error: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
        ),
      );
    } catch (e) {
      print('Error building project card: $e');
      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: ListTile(
          title: const Text('Error loading project'),
          subtitle: Text('Error: $e'),
        ),
      );
    }
  }

  Widget _buildJoinRequestCard(JoinRequest request, bool isReceived) {
    try {
      // Find which project this request belongs to (only for received requests)
      Project? project;
      if (isReceived) {
        try {
          project = myProjects.firstWhere(
            (p) => p.pendingRequests.any((r) => r.id == request.id),
            orElse:
                () =>
                    myProjects.isNotEmpty
                        ? myProjects.first
                        : Project(
                          id: '',
                          title: 'Unknown Project',
                          description: '',
                          status: 'open',
                          requiredSkills: [],
                          maxMembers: 5,
                          currentMembers: 1,
                          visibility: 'public',
                          createdAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                          creator: User.empty(),
                          members: [],
                        ),
          );
        } catch (e) {
          print('Error finding project for request: $e');
          // Handle case where no projects exist
        }
      }

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
                    child: Text(
                      request.user.name.isNotEmpty
                          ? request.user.name[0].toUpperCase()
                          : 'U',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.user.name.isNotEmpty
                              ? request.user.name
                              : 'Unknown User',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (isReceived && project != null)
                          Text(
                            'Requested to join ${project.title}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          )
                        else
                          Text(
                            'You requested to join this project',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
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

              // Different actions based on whether it's received or sent
              if (isReceived && project != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed:
                          () =>
                              _respondToRequest(project!.id, request.id, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      child: const Text('Decline'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed:
                          () =>
                              _respondToRequest(project!.id, request.id, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: const Text('Accept'),
                    ),
                  ],
                ),
              ] else if (!isReceived) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => _cancelJoinRequest(request.id),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      child: const Text('Cancel Request'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    } catch (e) {
      print('Error building join request card: $e');
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          title: const Text('Error loading request'),
          subtitle: Text('Error: $e'),
        ),
      );
    }
  }

  Future<void> _respondToRequest(
    String projectId,
    String requestId,
    bool accept,
  ) async {
    try {
      setState(() => _isLoading = true);

      final response = await ApiService.respondToJoinRequest(
        projectId,
        requestId,
        accept,
      );

      if (mounted) {
        setState(() => _isLoading = false);
      }

      if (response['success']) {
        if (mounted) {
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
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['error'] ?? 'Failed to process request'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error responding to request: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _cancelJoinRequest(String requestId) async {
    try {
      setState(() => _isLoading = true);

      final response = await ApiService.cancelJoinRequest(requestId);

      if (mounted) {
        setState(() => _isLoading = false);
      }

      if (response['success']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Join request cancelled'),
              backgroundColor: Colors.grey,
            ),
          );

          // Refresh data
          _loadTeamsData();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['error'] ?? 'Failed to cancel request'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error cancelling join request: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    try {
      _tabController.dispose();
    } catch (e) {
      print('Error disposing tab controller: $e');
    }
    super.dispose();
  }
}
