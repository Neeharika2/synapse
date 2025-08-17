import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/project_provider.dart';
import '../../services/api_service.dart';
import '../../models/project_model.dart';

class TeamDashboardScreen extends StatefulWidget {
  const TeamDashboardScreen({super.key});

  @override
  State<TeamDashboardScreen> createState() => _TeamDashboardScreenState();
}

class _TeamDashboardScreenState extends State<TeamDashboardScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  List<dynamic> _myTeams = [];
  List<dynamic> _joinedTeams = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load teams I created
      final myTeamsResponse = await ApiService.getProjects(
        status: 'my_projects',
      );
      if (myTeamsResponse['success']) {
        setState(() {
          _myTeams = myTeamsResponse['data'] ?? [];
        });
      }

      // Load teams I joined (but didn't create)
      final joinedTeamsResponse = await ApiService.getProjects(
        status: 'joined_projects',
      );
      if (joinedTeamsResponse['success']) {
        setState(() {
          _joinedTeams = joinedTeamsResponse['data'] ?? [];
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load teams: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Dashboard'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadTeams),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'My Teams'), Tab(text: 'Joined Teams')],
        ),
      ),
      body:
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
                      onPressed: _loadTeams,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
              : TabBarView(
                controller: _tabController,
                children: [_buildMyTeamsTab(), _buildJoinedTeamsTab()],
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/create-project');
        },
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Create New Team',
      ),
    );
  }

  Widget _buildMyTeamsTab() {
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
              onPressed: () {
                Navigator.pushNamed(context, '/create-project');
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Team'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
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
    );
  }

  Widget _buildJoinedTeamsTab() {
    if (_joinedTeams.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('Not part of any teams yet'),
            const SizedBox(height: 8),
            const Text(
              'Join existing projects to become part of a team',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/');
              },
              icon: const Icon(Icons.search),
              label: const Text('Browse Projects'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
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

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Recent';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 30) {
        return '${difference.inDays ~/ 30} months ago';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} days ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hours ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Recent';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return Colors.green;
      case 'in_progress':
      case 'in-progress':
        return Colors.blue;
      case 'completed':
        return Colors.purple;
      case 'archived':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
