const express = require('express');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
const { testConnection, initializeTables } = require('./config/database');
require('dotenv').config();

const authRoutes = require('./routes/auth');
const profileRoutes = require('./routes/profile');
const projectRoutes = require('./routes/projects');
const teamRoutes = require('./routes/teams');

const app = express();
const PORT = process.env.PORT || 3000;
const HOST = process.env.HOST || '0.0.0.0';

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100 // limit each IP to 100 requests per windowMs
});

// CORS configuration for network access
const corsOptions = {
  origin: '*', // Allow all origins for development
  credentials: true,
  optionsSuccessStatus: 200,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
};

// Middleware
app.use(limiter);
app.use(cors(corsOptions));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/profile', profileRoutes);
app.use('/api/projects', projectRoutes);
app.use('/api/teams', teamRoutes);

// Health check endpoint
app.get('/health', (req, res) => {
  console.log(`🏥 Health check requested from ${req.ip}`);
  res.status(200).json({ 
    status: 'OK', 
    message: 'Synapse API is running',
    timestamp: new Date().toISOString(),
    server: 'Node.js + Express',
    version: '1.0.0'
  });
});

// Root endpoint
app.get('/', (req, res) => {
  res.json({ 
    message: 'Synapse API Server', 
    health: '/health',
    api: '/api'
  });
});

// Initialize database and start server
const startServer = async () => {
  try {
    console.log('🔄 Testing database connection...');
    await testConnection();
    
    console.log('🔄 Initializing database tables...');
    await initializeTables();
    
    app.listen(PORT, HOST, () => {
      console.log(`🚀 Server is running on http://${HOST}:${PORT}`);
      console.log(`🏥 Health check: http://${HOST}:${PORT}/health`);
      console.log(`📡 API base URL: http://${HOST}:${PORT}/api`);
      console.log(`🌐 Network accessible at: http://192.168.193.205:${PORT}`);
    });
  } catch (error) {
    console.error('❌ Failed to start server:', error);
    process.exit(1);
  }
};

startServer();
