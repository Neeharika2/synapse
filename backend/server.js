const express = require('express');
const cors = require('cors');
const http = require('http');
const socketIo = require('socket.io');
const path = require('path');
require('dotenv').config();

// Import database configuration
const { testConnection, initializeTables } = require('./config/database');

// Import routes
const authRoutes = require('./routes/auth');
const profileRoutes = require('./routes/profile');
const projectsRoutes = require('./routes/projects');
const teamsRoutes = require('./routes/teams');

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// Socket.IO connection handling
const connectedUsers = new Map(); // userId -> socketId
const projectRooms = new Map(); // projectId -> Set of userIds

io.on('connection', (socket) => {
  console.log('🔌 New client connected:', socket.id);

  // Handle user authentication
  socket.on('authenticate', (data) => {
    const { userId, projectId } = data;
    if (userId && projectId) {
      connectedUsers.set(userId, socket.id);
      socket.userId = userId;
      socket.projectId = projectId;
      
      // Join project room
      socket.join(`project_${projectId}`);
      
      // Track project members
      if (!projectRooms.has(projectId)) {
        projectRooms.set(projectId, new Set());
      }
      projectRooms.get(projectId).add(userId);
      
      console.log(`👤 User ${userId} joined project ${projectId}`);
      
      // Notify other team members
      socket.to(`project_${projectId}`).emit('userJoined', {
        userId,
        message: 'A team member joined the chat'
      });
    }
  });

  // Handle chat messages
  socket.on('chatMessage', (data) => {
    const { projectId, userId, message, userName } = data;
    
    if (projectId && userId && message) {
      // Broadcast to all users in the project room
      io.to(`project_${projectId}`).emit('newMessage', {
        userId,
        userName,
        message,
        timestamp: new Date().toISOString()
      });
      
      console.log(`💬 Chat message in project ${projectId}: ${userName}: ${message}`);
    }
  });

  // Handle typing indicators
  socket.on('typing', (data) => {
    const { projectId, userId, userName, isTyping } = data;
    
    socket.to(`project_${projectId}`).emit('userTyping', {
      userId,
      userName,
      isTyping
    });
  });

  // Handle disconnection
  socket.on('disconnect', () => {
    console.log('🔌 Client disconnected:', socket.id);
    
    if (socket.userId && socket.projectId) {
      // Remove from tracking
      connectedUsers.delete(socket.userId);
      
      const projectMembers = projectRooms.get(socket.projectId);
      if (projectMembers) {
        projectMembers.delete(socket.userId);
        if (projectMembers.size === 0) {
          projectRooms.delete(socket.projectId);
        }
      }
      
      // Notify other team members
      socket.to(`project_${socket.projectId}`).emit('userLeft', {
        userId: socket.userId,
        message: 'A team member left the chat'
      });
    }
  });
});

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/profile', profileRoutes);
app.use('/api/projects', projectsRoutes);
app.use('/api/teams', teamsRoutes);

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    message: 'Synapse Backend is running',
    timestamp: new Date().toISOString(),
    connectedUsers: connectedUsers.size,
    activeProjects: projectRooms.size
  });
});

const PORT = process.env.PORT || 3000;
const HOST = process.env.HOST || '0.0.0.0';

// Initialize database and start server
const startServer = async () => {
  try {
    console.log('🔄 Testing database connection...');
    await testConnection();
    
    console.log('🔄 Initializing database tables...');
    await initializeTables();
    
    server.listen(PORT, HOST, () => {
      console.log(`🚀 Server is running on http://${HOST}:${PORT}`);
      console.log(`🏥 Health check: http://${HOST}:${PORT}/health`);
      console.log(`📡 API base URL: http://${HOST}:${PORT}/api`);
      console.log(`🌐 Network accessible at: http://192.168.193.205:${PORT}`);
      console.log(`🔌 Socket.IO enabled for real-time features`);
    });
  } catch (error) {
    console.error('❌ Failed to start server:', error);
    process.exit(1);
  }
};

startServer();
