const express = require('express');
const router = express.Router();
const db = require('../config/database');
const auth = require('../middleware/auth');

// Get user profile
router.get('/', auth, async (req, res) => {
  try {
    const userId = req.user.id;
    
    // Get user details
    const userQuery = `
      SELECT id, name, email, created_at
      FROM users
      WHERE id = ?
    `;
    
    // Get profile details
    const profileQuery = `
      SELECT college, department, skills, bio, credits
      FROM user_profiles
      WHERE user_id = ?
    `;
    
    // Get completed projects (projects where user is a member and has status 'completed')
    const completedProjectsQuery = `
      SELECT COUNT(*) AS completed_projects
      FROM project_team pt
      JOIN projects p ON pt.project_id = p.id
      WHERE pt.user_id = ? AND p.status = 'completed'
    `;
    
    // Get active projects (projects where user is a member and status is not 'completed')
    const activeProjectsQuery = `
      SELECT 
        p.id, 
        p.title, 
        p.description, 
        p.created_at,
        u.name as creator_name
      FROM project_team pt
      JOIN projects p ON pt.project_id = p.id
      JOIN users u ON p.created_by = u.id
      WHERE pt.user_id = ? AND (p.status IS NULL OR p.status != 'completed')
      
      UNION
      
      SELECT 
        p.id, 
        p.title, 
        p.description, 
        p.created_at,
        u.name as creator_name
      FROM projects p
      JOIN users u ON p.created_by = u.id
      WHERE p.created_by = ? AND (p.status IS NULL OR p.status != 'completed')
    `;
    
    // Execute queries
    const [userResult] = await db.promise().query(userQuery, [userId]);
    let [profileResult] = await db.promise().query(profileQuery, [userId]);
    const [completedResult] = await db.promise().query(completedProjectsQuery, [userId]);
    const [activeProjectsResult] = await db.promise().query(activeProjectsQuery, [userId, userId]);
    
    // If profile doesn't exist, create an empty one
    if (profileResult.length === 0) {
      await db.promise().query(
        'INSERT INTO user_profiles (user_id) VALUES (?)', 
        [userId]
      );
      [profileResult] = await db.promise().query(profileQuery, [userId]);
    }
    
    // Combine all data
    const userData = {
      ...userResult[0],
      ...profileResult[0],
      completed_projects: completedResult[0].completed_projects,
      active_projects: activeProjectsResult
    };
    
    res.json(userData);
  } catch (error) {
    console.error('Error fetching profile:', error);
    res.status(500).json({ error: 'Failed to fetch profile data' });
  }
});

// Update user profile
router.put('/', auth, async (req, res) => {
  try {
    const userId = req.user.id;
    const { college, department, skills, bio } = req.body;
    
    // Check if profile exists
    const [checkProfile] = await db.promise().query(
      'SELECT 1 FROM user_profiles WHERE user_id = ?', 
      [userId]
    );
    
    if (checkProfile.length === 0) {
      // Create profile if it doesn't exist
      await db.promise().query(
        'INSERT INTO user_profiles (user_id, college, department, skills, bio) VALUES (?, ?, ?, ?, ?)',
        [userId, college, department, skills, bio]
      );
    } else {
      // Update existing profile
      await db.promise().query(
        'UPDATE user_profiles SET college = ?, department = ?, skills = ?, bio = ? WHERE user_id = ?',
        [college, department, skills, bio, userId]
      );
    }
    
    res.json({ message: 'Profile updated successfully' });
  } catch (error) {
    console.error('Error updating profile:', error);
    res.status(500).json({ error: 'Failed to update profile' });
  }
});

module.exports = router;