const express = require('express');
const { pool } = require('../config/database');
const authMiddleware = require('../middleware/auth');

const router = express.Router();

// Get user profile
router.get('/', authMiddleware, async (req, res) => {
  try {
    const [profiles] = await pool.execute(`
      SELECT 
        u.id, u.name, u.email, u.avatar_url,
        p.branch, p.year_of_study, p.bio, p.skills,
        p.github_url, p.linkedin_url, p.portfolio_url
      FROM users u
      LEFT JOIN user_profiles p ON u.id = p.user_id
      WHERE u.id = ?
    `, [req.userId]);

    if (profiles.length === 0) {
      return res.status(404).json({ error: 'Profile not found' });
    }

    const profile = profiles[0];
    if (profile.skills) {
      profile.skills = JSON.parse(profile.skills);
    }

    res.json(profile);
  } catch (error) {
    console.error('Get profile error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Create/Update user profile
router.post('/setup', authMiddleware, async (req, res) => {
  try {
    const { branch, yearOfStudy, bio, skills, githubUrl, linkedinUrl, portfolioUrl } = req.body;

    // Check if profile exists
    const [existingProfiles] = await pool.execute(
      'SELECT id FROM user_profiles WHERE user_id = ?',
      [req.userId]
    );

    const skillsJson = JSON.stringify(skills || []);

    if (existingProfiles.length > 0) {
      // Update existing profile
      await pool.execute(`
        UPDATE user_profiles 
        SET branch = ?, year_of_study = ?, bio = ?, skills = ?,
            github_url = ?, linkedin_url = ?, portfolio_url = ?
        WHERE user_id = ?
      `, [branch, yearOfStudy, bio, skillsJson, githubUrl, linkedinUrl, portfolioUrl, req.userId]);
    } else {
      // Create new profile
      await pool.execute(`
        INSERT INTO user_profiles 
        (user_id, branch, year_of_study, bio, skills, github_url, linkedin_url, portfolio_url)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      `, [req.userId, branch, yearOfStudy, bio, skillsJson, githubUrl, linkedinUrl, portfolioUrl]);
    }

    res.json({ message: 'Profile updated successfully' });
  } catch (error) {
    console.error('Profile setup error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
