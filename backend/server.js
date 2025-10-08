const express = require('express');
const cors = require('cors');
const http = require('http');
const socketIo = require('socket.io');
require('dotenv').config();

const authRoutes = require('./routes/auth');
const projectRoutes = require('./routes/projects');
const teamRoutes = require('./routes/teams');
const chatRoutes = require('./routes/chat');
const fileRoutes = require('./routes/files');
const taskRoutes = require('./routes/tasks');
const meetingRoutes = require('./routes/meetings');
const profileRoutes = require('./routes/profile');

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: "http://localhost:3000",
    methods: ["GET", "POST"]
  }
});

const emailAuthRoutes = require('./routes/emailAuth');

// Middleware
app.use(cors());
app.use(express.json());

// Routes
app.use('/auth', emailAuthRoutes);
app.use('/api/auth', authRoutes);

// Add a specific route for checking email
app.use('/auth/check-email', (req, res, next) => {
  req.url = '/check-email';
  authRoutes(req, res, next);
});

app.use('/api/projects', projectRoutes);
app.use('/api/teams', teamRoutes);
app.use('/api/chat', chatRoutes);
app.use('/api/files', fileRoutes);
app.use('/api/tasks', taskRoutes);
app.use('/api/meetings', meetingRoutes);
app.use('/api/profile', profileRoutes);

// File upload folder
app.use('/uploads', express.static('uploads'));

// Socket.io connection
io.on('connection', (socket) => {
  console.log('New client connected:', socket.id);
  
  // Join project room
  socket.on('joinProject', (projectId) => {
    socket.join(`project-${projectId}`);
    console.log(`Socket ${socket.id} joined project-${projectId}`);
  });
  
  // Leave project room
  socket.on('leaveProject', (projectId) => {
    socket.leave(`project-${projectId}`);
    console.log(`Socket ${socket.id} left project-${projectId}`);
  });
  
  // Handle new messages
  socket.on('sendMessage', async (data) => {
    try {
      const { projectId, userId, message } = data;
      
      // Save to database (handled by chatRoutes)
      const savedMessage = await require('./controllers/chatController').saveMessage(projectId, userId, message);
      
      // Broadcast to all in the project room
      io.to(`project-${projectId}`).emit('newMessage', savedMessage);
    } catch (error) {
      console.error('Error handling message:', error);
      socket.emit('error', { message: 'Failed to send message' });
    }
  });
  
  // Disconnect
  socket.on('disconnect', () => {
    console.log('Client disconnected:', socket.id);
  });
});

const PORT = process.env.PORT || 5000;
server.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
