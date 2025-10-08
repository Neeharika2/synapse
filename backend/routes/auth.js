const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const db = require('../config/database');
const router = express.Router();

// Check if email exists
router.post('/check-email', (req, res) => {
  try {
    const { email } = req.body;
    
    if (!email) {
      return res.status(400).json({ error: 'Email is required' });
    }
    
    // Query database to check if email exists
    db.query('SELECT id FROM users WHERE email = ?', [email], (err, results) => {
      if (err) {
        console.error('Database error during email check:', err);
        return res.status(500).json({ error: 'Database error' });
      }
      
      // Return result indicating whether email exists
      return res.json({ exists: results.length > 0 });
    });
  } catch (error) {
    console.error('Error checking email existence:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// Register
router.post('/register', async (req, res) => {
  try {
    const { name, email, password } = req.body;
    
    // Check if user exists
    db.query('SELECT email FROM users WHERE email = ?', [email], async (err, results) => {
      if (err) return res.status(500).json({ error: 'Database error' });
      if (results.length > 0) return res.status(409).json({ error: 'Email already exists' });
      
      // Hash password
      const hashedPassword = await bcrypt.hash(password, 10);
      
      // Insert user
      db.query('INSERT INTO users (name, email, password) VALUES (?, ?, ?)', 
        [name, email, hashedPassword], (err, result) => {
          if (err) return res.status(500).json({ error: 'Database error' });
          
          const token = jwt.sign({ userId: result.insertId }, process.env.JWT_SECRET);
          res.json({ token, user: { id: result.insertId, name, email } });
        });
    });
  } catch (error) {
    res.status(500).json({ error: 'Server error' });
  }
});

// Login
router.post('/login', (req, res) => {
  try {
    const { email, password } = req.body;
    
    db.query('SELECT * FROM users WHERE email = ?', [email], async (err, results) => {
      if (err) return res.status(500).json({ error: 'Database error' });
      if (results.length === 0) return res.status(400).json({ error: 'Invalid credentials' });
      
      const user = results[0];
      const isMatch = await bcrypt.compare(password, user.password);
      
      if (!isMatch) return res.status(400).json({ error: 'Invalid credentials' });
      
      const token = jwt.sign({ userId: user.id }, process.env.JWT_SECRET);
      res.json({ token, user: { id: user.id, name: user.name, email: user.email } });
    });
  } catch (error) {
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
