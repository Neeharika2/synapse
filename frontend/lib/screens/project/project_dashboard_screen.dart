import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/project_provider.dart';
import '../../models/project_model.dart';
import '../../models/team_features_model.dart';
import '../../models/chat_message_model.dart';
import '../../models/todo_model.dart';
import '../../models/project_file_model.dart';
import '../../models/meeting_model.dart';
import '../../services/api_service.dart';
import '../../services/chat_service.dart';
import '../../services/chat_api_service.dart' as chat_api;
import '../../services/todos_api_service.dart' as todos_api;
import '../../services/files_api_service.dart' as files_api;
import '../../services/meetings_api_service.dart' as meetings_api;

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

  // Chat state
  final List<ChatMessage> _chatMessages = [];
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  bool _isTyping = false;

  // Todos state
  List<Todo> _todos = [];
  bool _isLoadingTodos = false;

  // Files state
  List<ProjectFile> _files = [];
  bool _isLoadingFiles = false;

  // Meetings state
  List<ProjectMeeting> _meetings = [];
  bool _isLoadingMeetings = false;

  @override
  void initState() {
    super.initState();
    // Initialize tab controller with proper length based on user role
    _tabController = TabController(length: 5, vsync: this);
    // We'll load the project data once the widget is fully built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProjectData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateTabController();
  }

  void _updateTabController() {
    // Update tab controller length based on user role after project data is loaded
    if (_project != null) {
      try {
        final newLength = _isCreator() ? 5 : 4;
        if (_tabController.length != newLength) {
          _tabController.dispose();
          _tabController = TabController(length: newLength, vsync: this);
        }
      } catch (e) {
        print('Error updating tab controller: $e');
      }
    }
  }

  Future<void> _loadProjectData() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final projectProvider = Provider.of<ProjectProvider>(
        context,
        listen: false,
      );

      final projectId = ModalRoute.of(context)?.settings.arguments as String?;

      if (projectId == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        print('⚠️ No project ID provided');
        return;
      }

      print('🔍 Fetching project details: $projectId');

      try {
        // Load project details
        final success = await projectProvider.getProjectDetails(projectId);
        final userId = authProvider.user?['id']?.toString();

        print('📡 Project details loaded successfully: $success');

        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }

        if (success) {
          final project = projectProvider.currentProject;
          print('🧩 Project data received: ${project?.title}');
          print('🧩 Pending requests: ${project?.pendingRequests.length}');

          if (mounted) {
            setState(() {
              _project = project;
              _isMember = userId != null &&
                  project != null &&
                  (project.creator.id == userId ||
                      project.members.any((member) => member.id == userId));
            });

            // Update tab controller based on user role
            _updateTabController();
          }

          // Load additional data if user is a member
          if (_isMember) {
            _loadChatHistory();
            _loadTodos();
            _loadFiles();
            _loadMeetings();
            _initializeChat();
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(projectProvider.errorMessage),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        print('Error loading project data: $e');
        if (mounted) {
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
    } catch (e) {
      print('Error in _loadProjectData: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _initializeChat() {
    if (_project != null) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?['id']?.toString();
      final userName = authProvider.user?['name'] ?? 'Unknown User';

      if (userId != null) {
        ChatService.instance.onMessageReceived = _onMessageReceived;
        ChatService.instance.onUserJoined = _onUserJoined;
        ChatService.instance.onUserLeft = _onUserLeft;
        ChatService.instance.onUserTyping = _onUserTyping;
        ChatService.instance.onConnected = _onChatConnected;
        ChatService.instance.onDisconnected = _onChatDisconnected;

        ChatService.instance.joinProject(_project!.id, userId, userName);
      }
    }
  }

  void _onMessageReceived(Map<String, dynamic> data) {
    if (mounted) {
      setState(() {
        _chatMessages.add(ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          projectId: _project?.id ?? '',
          userId: data['userId'] ?? '',
          userName: data['userName'] ?? 'Unknown User',
          message: data['message'] ?? '',
          createdAt: DateTime.now(),
        ));
      });
      _scrollToBottom();
    }
  }

  void _onUserJoined(Map<String, dynamic> data) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(data['message'] ?? 'A team member joined'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _onUserLeft(Map<String, dynamic> data) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(data['message'] ?? 'A team member left'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _onUserTyping(Map<String, dynamic> data) {
    // Handle typing indicators
    final isTyping = data['is_typing'] ?? false;

    if (mounted && isTyping) {
      setState(() {
        _isTyping = true;
      });

      // Auto-reset typing indicator after a delay
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _isTyping = false;
          });
        }
      });
    }
  }

  void _onChatConnected() {
    print('🔌 Chat connected');
  }

  void _onChatDisconnected() {
    print('🔌 Chat disconnected');
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _loadChatHistory() async {
    if (_project == null) return;

    try {
      final response =
          await chat_api.ChatApiService.getChatHistory(_project!.id);
      if (response['success'] && response['data'] != null) {
        final messages = (response['data'] as List)
            .map((msg) => ChatMessage.fromJson(msg))
            .toList();

        if (mounted) {
          setState(() {
            _chatMessages.clear();
            _chatMessages.addAll(messages);
          });
          _scrollToBottom();
        }
      }
    } catch (e) {
      print('Error loading chat history: $e');
    }
  }

  Future<void> _loadTodos() async {
    if (_project == null) return;

    setState(() => _isLoadingTodos = true);
    try {
      final response =
          await todos_api.TodosApiService.getProjectTodos(_project!.id);
      if (response['success'] && response['data'] != null) {
        final todos = (response['data'] as List)
            .map((todo) => Todo.fromJson(todo))
            .toList();

        if (mounted) {
          setState(() {
            _todos = todos;
            _isLoadingTodos = false;
          });
        }
      }
    } catch (e) {
      print('Error loading todos: $e');
      if (mounted) {
        setState(() => _isLoadingTodos = false);
      }
    }
  }

  Future<void> _loadFiles() async {
    if (_project == null) return;

    setState(() => _isLoadingFiles = true);
    try {
      final response =
          await files_api.FilesApiService.getProjectFiles(_project!.id);
      if (response['success'] && response['data'] != null) {
        final files = (response['data'] as List)
            .map((file) => ProjectFile.fromJson(file))
            .toList();

        if (mounted) {
          setState(() {
            _files = files;
            _isLoadingFiles = false;
          });
        }
      }
    } catch (e) {
      print('Error loading files: $e');
      if (mounted) {
        setState(() => _isLoadingFiles = false);
      }
    }
  }

  Future<void> _loadMeetings() async {
    if (_project == null) return;

    setState(() => _isLoadingMeetings = true);
    try {
      final response = await meetings_api.MeetingsApiService.getProjectMeetings(
          _project!.id);
      if (response['success'] && response['data'] != null) {
        final meetings = (response['data'] as List)
            .map((meeting) => ProjectMeeting.fromJson(meeting))
            .toList();

        if (mounted) {
          setState(() {
            _meetings = meetings;
            _isLoadingMeetings = false;
          });
        }
      }
    } catch (e) {
      print('Error loading meetings: $e');
      if (mounted) {
        setState(() => _isLoadingMeetings = false);
      }
    }
  }

  void _sendMessage() {
    final message = _chatController.text.trim();
    if (message.isNotEmpty) {
      ChatService.instance.sendMessage(message);
      _chatController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      if (_isLoading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }

      if (_project == null) {
        return const Scaffold(
          body: Center(child: Text('Project not found')),
        );
      }

      return Scaffold(
        appBar: AppBar(
          title: Text(_project!.title),
          backgroundColor: const Color(0xFF6366F1),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Column(
          children: [
            // Project Header
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF6366F1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _project!.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _project!.description,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildAvatarStack(),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_project!.currentMembers}/${_project!.maxMembers} members',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'Created by ${_project!.creator.name}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!_isMember)
                        ElevatedButton(
                          onPressed: () async {
                            try {
                              final projectProvider =
                                  Provider.of<ProjectProvider>(
                                context,
                                listen: false,
                              );
                              final success = await projectProvider
                                  .joinProject(_project!.id);
                              if (success) {
                                if (mounted) {
                                  setState(() {
                                    _isMember = true;
                                  });
                                  ScaffoldMessenger.of(
                                    context,
                                  ).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Successfully joined the project!',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                  // Load additional data after joining
                                  _loadChatHistory();
                                  _loadTodos();
                                  _loadFiles();
                                  _loadMeetings();
                                  _initializeChat();
                                }
                              } else {
                                if (mounted) {
                                  ScaffoldMessenger.of(
                                    context,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        projectProvider.errorMessage,
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            } catch (e) {
                              print('Error joining project: $e');
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Error joining project: $e',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          child: const Text('Join Project'),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Tab Bar
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF6366F1),
                unselectedLabelColor: Colors.grey,
                indicatorColor: const Color(0xFF6366F1),
                tabs: [
                  const Tab(icon: Icon(Icons.chat), text: 'Chat'),
                  const Tab(icon: Icon(Icons.checklist), text: 'Todos'),
                  const Tab(icon: Icon(Icons.folder), text: 'Files'),
                  const Tab(icon: Icon(Icons.event), text: 'Schedule'),
                  if (_isCreator())
                    const Tab(icon: Icon(Icons.person_add), text: 'Requests'),
                ],
              ),
            ),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildChatTab(),
                  _buildTodosTab(),
                  _buildFilesTab(),
                  _buildScheduleTab(),
                  if (_isCreator()) _buildRequestsTab(),
                ],
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      print('Error in build method: $e');
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Something went wrong',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Error: $e',
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
  }

  bool _isCreator() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return _project != null &&
        authProvider.user != null &&
        _project!.creator.id == authProvider.user!['id'].toString();
  }

  Widget _buildChatTab() {
    try {
      return Column(
        children: [
          // Chat Messages
          Expanded(
            child: _chatMessages.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w500),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Start the conversation!',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _chatScrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _chatMessages.length,
                    itemBuilder: (context, index) {
                      final message = _chatMessages[index];
                      final isMe = message.userId ==
                          Provider.of<AuthProvider>(context, listen: false)
                              .user?['id']
                              ?.toString();

                      return _buildChatMessage(
                        message.userName ?? 'Unknown User',
                        message.message,
                        _formatDate(message.createdAt.toIso8601String()),
                        isMe,
                      );
                    },
                  ),
          ),

          // Typing indicator
          if (_isTyping)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Someone is typing...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

          // Chat Input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: InputBorder.none,
                    ),
                    onChanged: (value) {
                      ChatService.instance
                          .sendTypingIndicator(value.isNotEmpty);
                    },
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send),
                  color: const Color(0xFF6366F1),
                ),
              ],
            ),
          ),
        ],
      );
    } catch (e) {
      print('Error building chat tab: $e');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Error loading chat'),
            const SizedBox(height: 8),
            Text(
              'Error: $e',
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
  }

  Widget _buildTodosTab() {
    try {
      return Column(
        children: [
          // Todos Header
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFFF9FAFB),
            child: Row(
              children: [
                const Text(
                  'Project Tasks:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _showAddTodoDialog(),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Task'),
                ),
              ],
            ),
          ),

          // Todos List
          Expanded(
            child: _isLoadingTodos
                ? const Center(child: CircularProgressIndicator())
                : _todos.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.checklist_outlined,
                                size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No tasks yet',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w500),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Create your first task to get started!',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _todos.length,
                        itemBuilder: (context, index) {
                          final todo = _todos[index];
                          return _buildTodoItem(todo);
                        },
                      ),
          ),
        ],
      );
    } catch (e) {
      print('Error building todos tab: $e');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Error loading todos'),
            const SizedBox(height: 8),
            Text(
              'Error: $e',
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
  }

  Widget _buildFilesTab() {
    try {
      return Column(
        children: [
          // Files Header
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFFF9FAFB),
            child: Row(
              children: [
                const Text(
                  'Project Files:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _showAddFileDialog(),
                  icon: const Icon(Icons.upload, size: 16),
                  label: const Text('Upload'),
                ),
              ],
            ),
          ),

          // Files List
          Expanded(
            child: _isLoadingFiles
                ? const Center(child: CircularProgressIndicator())
                : _files.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.folder_outlined,
                                size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No files yet',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w500),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Upload your first file to get started!',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _files.length,
                        itemBuilder: (context, index) {
                          final file = _files[index];
                          return _buildFileItem(file);
                        },
                      ),
          ),
        ],
      );
    } catch (e) {
      print('Error building files tab: $e');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Error loading files'),
            const SizedBox(height: 8),
            Text(
              'Error: $e',
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
  }

  Widget _buildScheduleTab() {
    try {
      return Column(
        children: [
          // Schedule Header
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFFF9FAFB),
            child: Row(
              children: [
                const Text(
                  'Project Schedule:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _showAddMeetingDialog(),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Event'),
                ),
              ],
            ),
          ),

          // Meetings List
          Expanded(
            child: _isLoadingMeetings
                ? const Center(child: CircularProgressIndicator())
                : _meetings.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.event_outlined,
                                size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No meetings scheduled',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w500),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Schedule your first meeting to get started!',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _meetings.length,
                        itemBuilder: (context, index) {
                          final meeting = _meetings[index];
                          return _buildMeetingItem(meeting);
                        },
                      ),
          ),
        ],
      );
    } catch (e) {
      print('Error building schedule tab: $e');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Error loading schedule'),
            const SizedBox(height: 8),
            Text(
              'Error: $e',
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
  }

  Widget _buildRequestsTab() {
    try {
      // Create two tabs for received and sent requests
      return DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Container(
              color: Colors.grey[100],
              child: const TabBar(
                labelColor: Color(0xFF6366F1),
                unselectedLabelColor: Colors.grey,
                indicatorColor: Color(0xFF6366F1),
                tabs: [
                  Tab(
                    text: 'RECEIVED',
                    icon: Icon(Icons.download_rounded),
                  ),
                  Tab(
                    text: 'SENT',
                    icon: Icon(Icons.upload_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // Received requests tab (pending requests for this project)
                  _buildReceivedRequestsTab(),

                  // Sent requests tab (requests sent by the current user)
                  _buildSentRequestsTab(),
                ],
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      print('Error building requests tab: $e');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Error loading requests'),
            const SizedBox(height: 8),
            Text(
              'Error: $e',
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
  }

  Widget _buildReceivedRequestsTab() {
    if (_project == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Make sure we only display requests for THIS project
    final requestsForThisProject = _project!.pendingRequests
        .where((req) => req.projectId == _project!.id)
        .toList();

    print(
        '📊 Found ${requestsForThisProject.length} requests for project ${_project!.id}');
    print('📊 Total pending requests: ${_project!.pendingRequests.length}');

    if (requestsForThisProject.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_add_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No pending requests',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Text(
              'All join requests have been processed',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: requestsForThisProject.length,
      itemBuilder: (context, index) {
        try {
          final request = requestsForThisProject[index];
          print(
              '🧩 Building request card for project ${request.projectId}, current project: ${_project!.id}');
          return _buildJoinRequestCard(request);
        } catch (e) {
          print('Error building request item $index: $e');
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: ListTile(
              title: const Text('Error loading request'),
              subtitle: Text('Error: $e'),
            ),
          );
        }
      },
    );
  }

  Widget _buildSentRequestsTab() {
    // We'll need to load the sent requests from the API
    return FutureBuilder<Map<String, dynamic>>(
      future: ApiService.getSentRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text('Error loading sent requests'),
                const SizedBox(height: 8),
                Text(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData ||
            snapshot.data!['success'] != true ||
            snapshot.data!['data'] == null ||
            snapshot.data!['data'] is! List ||
            (snapshot.data!['data'] as List).isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.send_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text(
                  'No sent requests',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                const Text(
                  'You haven\'t sent any join requests',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        final sentRequests = snapshot.data!['data'] as List;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sentRequests.length,
          itemBuilder: (context, index) {
            try {
              final request = sentRequests[index];
              return _buildSentRequestCard(request);
            } catch (e) {
              print('Error building sent request item $index: $e');
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  title: const Text('Error loading request'),
                  subtitle: Text('Error: $e'),
                ),
              );
            }
          },
        );
      },
    );
  }

  Widget _buildJoinRequestCard(JoinRequest request) {
    try {
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
                          request.user.name.isNotEmpty
                              ? request.user.name
                              : 'Unknown User',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          request.user.email,
                          style: const TextStyle(color: Colors.grey),
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
                    ),
                    child: const Text('Decline'),
                  ),
                  const SizedBox(width: 8),
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
    } catch (e) {
      print('Error building join request card: $e');
      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: ListTile(
          title: const Text('Error loading request'),
          subtitle: Text('Error: $e'),
        ),
      );
    }
  }

  Widget _buildSentRequestCard(dynamic requestData) {
    try {
      // Extract data from the request object
      final String projectTitle =
          requestData['project_title'] ?? 'Unknown Project';
      final String requestId = requestData['id']?.toString() ?? '';
      final String status = requestData['status'] ?? 'pending';
      final String message = requestData['message'] ?? '';
      final String createdAt = requestData['created_at'] ?? '';

      // Format status for display
      String statusText = 'Pending';
      Color statusColor = Colors.orange;
      if (status == 'accepted') {
        statusText = 'Accepted';
        statusColor = Colors.green;
      } else if (status == 'rejected') {
        statusText = 'Rejected';
        statusColor = Colors.red;
      }

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
                    child: Icon(Icons.work_outline, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          projectTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Requested on: $createdAt',
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              if (message.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(message),
                ),
              ],
              const SizedBox(height: 16),
              if (status == 'pending')
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => _cancelJoinRequest(requestId),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      child: const Text('Cancel Request'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      );
    } catch (e) {
      print('Error building sent request card: $e');
      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: ListTile(
          title: const Text('Error loading request'),
          subtitle: Text('Error: $e'),
        ),
      );
    }
  }

  Future<void> _respondToJoinRequest(String requestId, bool accept) async {
    try {
      // Show loading indicator
      if (mounted) {
        setState(() => _isLoading = true);
      }

      print(
          '🚀 Responding to join request: $requestId, action: ${accept ? 'accept' : 'decline'}');

      final response = await ApiService.respondToJoinRequest(
        _project!.id,
        requestId,
        accept,
      );

      print('📡 Response received: $response');

      if (response['success']) {
        if (mounted) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                accept ? 'User added to the project' : 'Request declined',
              ),
              backgroundColor: accept ? Colors.green : Colors.grey,
            ),
          );

          // Remove the request from the UI immediately for better UX
          setState(() {
            if (_project != null) {
              _project!.pendingRequests
                  .removeWhere((req) => req.id == requestId);
            }
          });

          // Refresh project data to update member list and pending requests
          await _loadProjectData();
        }
      } else {
        if (mounted) {
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['error'] ?? 'Failed to process request'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error responding to join request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _cancelJoinRequest(String requestId) async {
    try {
      // Show loading indicator
      if (mounted) {
        setState(() => _isLoading = true);
      }

      print('🚀 Canceling join request: $requestId');

      final response = await ApiService.cancelJoinRequest(requestId);

      print('📡 Response received: $response');

      if (response['success']) {
        if (mounted) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Request canceled successfully'),
              backgroundColor: Colors.green,
            ),
          );

          // Refresh the sent requests list
          setState(() {});
        }
      } else {
        if (mounted) {
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['error'] ?? 'Failed to cancel request'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error canceling join request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
                sender.isNotEmpty ? sender[0].toUpperCase() : 'U',
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
                sender.isNotEmpty ? sender[0].toUpperCase() : 'U',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTodoItem(Todo todo) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          todo.status == 'completed'
              ? Icons.check_circle
              : Icons.radio_button_unchecked,
          color: todo.status == 'completed' ? Colors.green : Colors.grey,
        ),
        title: Text(
          todo.title,
          style: TextStyle(
            decoration:
                todo.status == 'completed' ? TextDecoration.lineThrough : null,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (todo.description != null && todo.description!.isNotEmpty)
              Text(todo.description!),
            const SizedBox(height: 4),
            Row(
              children: [
                _buildPriorityChip(todo.priority),
                const SizedBox(width: 8),
                if (todo.assignedToName != null)
                  Text('Assigned to ${todo.assignedToName}'),
              ],
            ),
            if (todo.dueDate != null)
              Text(
                'Due: ${_formatDate(todo.dueDate!.toIso8601String())}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleTodoAction(value, todo),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Text('Edit'),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityChip(String priority) {
    Color color;
    switch (priority.toLowerCase()) {
      case 'high':
        color = Colors.red;
        break;
      case 'urgent':
        color = Colors.purple;
        break;
      case 'medium':
        color = Colors.orange;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        priority.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildFileItem(ProjectFile file) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getFileTypeColor(file.fileType).withOpacity(0.2),
          child: Icon(
            _getFileTypeIcon(file.fileType),
            color: _getFileTypeColor(file.fileType),
          ),
        ),
        title: Text(file.fileName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (file.fileSize != null)
              Text('${_formatFileSize(file.fileSize!)}'),
            Text('Uploaded by ${file.uploadedByName ?? 'Unknown'}'),
            Text(
              _formatDate(file.uploadedAt.toIso8601String()),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleFileAction(value, file),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'download',
              child: Text('Download'),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeetingItem(ProjectMeeting meeting) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFF6366F1),
          child: Icon(Icons.event, color: Colors.white),
        ),
        title: Text(meeting.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (meeting.description != null && meeting.description!.isNotEmpty)
              Text(meeting.description!),
            const SizedBox(height: 4),
            Text(
              '${_formatDate(meeting.meetingDate.toIso8601String())} at ${meeting.meetingTime}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            Text('Duration: ${meeting.duration} minutes'),
            if (meeting.platform != null) Text('Platform: ${meeting.platform}'),
            Text(
              'Created by ${meeting.createdByName ?? 'Unknown'}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleMeetingAction(value, meeting),
          itemBuilder: (context) => [
            if (meeting.meetingUrl != null)
              const PopupMenuItem(
                value: 'join',
                child: Text('Join Meeting'),
              ),
            const PopupMenuItem(
              value: 'edit',
              child: Text('Edit'),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }

  Color _getFileTypeColor(String? fileType) {
    if (fileType == null) return Colors.grey;

    switch (fileType.toLowerCase()) {
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Colors.green;
      case 'mp4':
      case 'avi':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getFileTypeIcon(String? fileType) {
    if (fileType == null) return Icons.insert_drive_file;

    switch (fileType.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      case 'mp4':
      case 'avi':
        return Icons.video_file;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  void _handleTodoAction(String action, Todo todo) {
    switch (action) {
      case 'edit':
        _showEditTodoDialog(todo);
        break;
      case 'delete':
        _deleteTodo(todo);
        break;
    }
  }

  void _handleFileAction(String action, ProjectFile file) {
    switch (action) {
      case 'download':
        // Implement file download
        break;
      case 'delete':
        _deleteFile(file);
        break;
    }
  }

  void _handleMeetingAction(String action, ProjectMeeting meeting) {
    switch (action) {
      case 'join':
        // Implement meeting join
        break;
      case 'edit':
        _showEditMeetingDialog(meeting);
        break;
      case 'delete':
        _deleteMeeting(meeting);
        break;
    }
  }

  void _showAddTodoDialog() {
    // TODO: Implement add todo dialog
  }

  void _showEditTodoDialog(Todo todo) {
    // TODO: Implement edit todo dialog
  }

  void _deleteTodo(Todo todo) {
    // TODO: Implement delete todo
  }

  void _showAddFileDialog() {
    // TODO: Implement add file dialog
  }

  void _deleteFile(ProjectFile file) {
    // TODO: Implement delete file
  }

  void _showAddMeetingDialog() {
    // TODO: Implement add meeting dialog
  }

  void _showEditMeetingDialog(ProjectMeeting meeting) {
    // TODO: Implement edit meeting dialog
  }

  void _deleteMeeting(ProjectMeeting meeting) {
    // TODO: Implement delete meeting
  }

  String _formatDate(String isoDateString) {
    try {
      final dateTime = DateTime.tryParse(isoDateString);
      if (dateTime == null) {
        return 'Recently';
      }

      final now = DateTime.now();
      final difference = now.difference(dateTime);

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
      print('Error formatting date: $e');
      return 'Recently';
    }
  }

  @override
  void dispose() {
    try {
      ChatService.instance.leaveProject();
      _tabController.dispose();
      _chatController.dispose();
      _chatScrollController.dispose();
    } catch (e) {
      print('Error disposing: $e');
    }
    super.dispose();
  }
}
