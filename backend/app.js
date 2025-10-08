const express = require('express');
const cors = require('cors');
const jwt = require('jsonwebtoken');
require('dotenv').config();

const db = require('./config/database');
const auth = require('./middleware/auth');

// Import routes
const emailAuthRoutes = require('./routes/emailAuth');
const projectRoutes = require('./routes/projects');
const teamsRoutes = require('./routes/teams');
const profileRoutes = require('./routes/profile');
const chatRoutes = require('./routes/chat');
const filesRoutes = require('./routes/files');
const tasksRoutes = require('./routes/tasks');
const meetingsRoutes = require('./routes/meetings');

const app = express();

// CORS configuration - allow frontend origin
app.use(cors({
  origin: 'http://localhost:3000',
  credentials: true
}));

// Body parsing middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Routes
app.use('/auth', emailAuthRoutes);
app.use('/api/projects', auth, projectRoutes);
app.use('/api/teams', auth, teamsRoutes);
app.use('/api/profile', auth, profileRoutes);
app.use('/api/chat', auth, chatRoutes);
app.use('/api/files', auth, filesRoutes);
app.use('/api/tasks', auth, tasksRoutes);
app.use('/api/meetings', auth, meetingsRoutes);

// User info endpoint (for frontend to get current user data)
app.get('/api/user', auth, async (req, res) => {
  try {
    const userId = req.user.id;
    
    // Get user details with profile
    const userQuery = `
      SELECT 
        u.id, u.name, u.email, u.created_at,
        up.college, up.department, up.skills, up.bio, up.credits
      FROM users u
      LEFT JOIN user_profiles up ON u.id = up.user_id
      WHERE u.id = ?
    `;
    
    db.query(userQuery, [userId], (err, results) => {
      if (err) {
        console.error('Error fetching user data:', err);
        return res.status(500).json({ error: 'Database error' });
      }
      
      if (results.length === 0) {
        return res.status(404).json({ error: 'User not found' });
      }
      
      const user = results[0];
      
      res.json({
        success: true,
        user: {
          id: user.id,
          name: user.name,
          email: user.email,
          created_at: user.created_at,
          college: user.college,
          department: user.department,
          skills: user.skills,
          bio: user.bio,
          credits: user.credits || 0
        }
      });
    });
    
  } catch (error) {
    console.error('Error in /api/user endpoint:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Global error handler:', err);
  res.status(500).json({ 
    error: 'Internal server error',
    message: process.env.NODE_ENV === 'development' ? err.message : 'Something went wrong'
  });
});

const PORT = process.env.PORT || 5000;

app.listen(PORT, () => {
  console.log(`🚀 Synapse server running on port ${PORT}`);
});

module.exports = app;
