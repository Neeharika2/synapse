import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../services/api_service.dart';

typedef MessageCallback = void Function(Map<String, dynamic>);
typedef StatusCallback = void Function();

class ChatService {
  static final ChatService _instance = ChatService._internal();
  static ChatService get instance => _instance;

  // Socket connection
  IO.Socket? _socket;
  String? _currentProjectId;
  String? _currentUserId;
  String? _currentUserName;

  // Callbacks
  MessageCallback? onMessageReceived;
  MessageCallback? onUserJoined;
  MessageCallback? onUserLeft;
  MessageCallback? onUserTyping;
  StatusCallback? onConnected;
  StatusCallback? onDisconnected;

  ChatService._internal();

  void _initializeSocket() {
    if (_socket != null) return;

    try {
      _socket = IO.io(ApiService.serverUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': true,
      });

      // Set up socket event handlers
      _socket!.on('connect', (_) {
        print('🔌 Socket connected: ${_socket!.id}');
        if (onConnected != null) onConnected!();
      });

      _socket!.on('disconnect', (_) {
        print('🔌 Socket disconnected');
        if (onDisconnected != null) onDisconnected!();
      });

      _socket!.on('message', (data) {
        print('📩 Message received: $data');
        if (onMessageReceived != null) onMessageReceived!(data);
      });

      _socket!.on('user_joined', (data) {
        print('👋 User joined: $data');
        if (onUserJoined != null) onUserJoined!(data);
      });

      _socket!.on('user_left', (data) {
        print('👋 User left: $data');
        if (onUserLeft != null) onUserLeft!(data);
      });

      _socket!.on('typing', (data) {
        if (onUserTyping != null) onUserTyping!(data);
      });

      _socket!.on('error', (error) => print('⚠️ Socket error: $error'));
    } catch (e) {
      print('⚠️ Error initializing socket: $e');
    }
  }

  void joinProject(String projectId, String userId, String userName) {
    try {
      _currentProjectId = projectId;
      _currentUserId = userId;
      _currentUserName = userName;

      _initializeSocket();

      if (_socket != null && _socket!.connected) {
        _socket!.emit('join_project', {
          'project_id': projectId,
          'user_id': userId,
          'user_name': userName,
        });
      } else {
        print('⚠️ Socket not connected, unable to join project');
        // Try reconnect
        _socket?.connect();
      }
    } catch (e) {
      print('⚠️ Error joining project chat: $e');
    }
  }

  void leaveProject() {
    try {
      if (_socket != null && _currentProjectId != null && _currentUserId != null) {
        _socket!.emit('leave_project', {
          'project_id': _currentProjectId,
          'user_id': _currentUserId,
          'user_name': _currentUserName,
        });
      }
    } catch (e) {
      print('⚠️ Error leaving project chat: $e');
    }
  }

  void sendMessage(String message) {
    try {
      if (_socket != null && _currentProjectId != null && _currentUserId != null) {
        _socket!.emit('send_message', {
          'project_id': _currentProjectId,
          'user_id': _currentUserId,
          'user_name': _currentUserName,
          'message': message,
        });
      }
    } catch (e) {
      print('⚠️ Error sending message: $e');
    }
  }

  void sendTypingIndicator(bool isTyping) {
    try {
      if (_socket != null && _currentProjectId != null && _currentUserId != null) {
        _socket!.emit('typing', {
          'project_id': _currentProjectId,
          'user_id': _currentUserId,
          'user_name': _currentUserName,
          'is_typing': isTyping,
        });
      }
    } catch (e) {
      print('⚠️ Error sending typing indicator: $e');
    }
  }

  void dispose() {
    leaveProject();
    _socket?.disconnect();
    _socket = null;
    _currentProjectId = null;
    _currentUserId = null;
    _currentUserName = null;
  }
}
    