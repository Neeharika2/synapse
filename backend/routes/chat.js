const express = require('express');
const router = express.Router();
const db = require('../config/database');
const auth = require('../middleware/auth');

// Get all messages for a project
router.get('/:projectId', auth, async (req, res) => {
  try {
    const { projectId } = req.params;
    const userId = req.user.id;
    
    // Check if chat_messages table exists
    const checkTableQuery = `
      SELECT COUNT(*) as count FROM information_schema.tables 
      WHERE table_schema = DATABASE() AND table_name = 'chat_messages'
    `;
    
    const [tableCheck] = await db.promise().query(checkTableQuery);
    if (tableCheck[0].count === 0) {
      // Table doesn't exist, return empty array
      return res.json([]);
    }
    
    // Check if user is authorized to view this project
    const userCheckQuery = `
      SELECT 1 FROM projects WHERE id = ? AND created_by = ?
      UNION
      SELECT 1 FROM project_team WHERE project_id = ? AND user_id = ?
    `;
    
    const [userCheck] = await db.promise().query(userCheckQuery, [
      projectId, 
      userId,
      projectId,
      userId
    ]);
    
    if (userCheck.length === 0) {
      return res.status(403).json({ error: 'You do not have access to this project' });
    }
    
    // Get all messages
    const query = `
      SELECT 
        cm.id, 
        cm.message, 
        cm.created_at, 
        u.id as user_id, 
        u.name as user_name
      FROM chat_messages cm
      JOIN users u ON cm.user_id = u.id
      WHERE cm.project_id = ?
      ORDER BY cm.created_at ASC
    `;
    
    const [rows] = await db.promise().query(query, [projectId]);
    res.json(rows);
  } catch (error) {
    console.error('Error fetching chat messages:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// Send a message
router.post('/:projectId', auth, async (req, res) => {
  try {
    const { projectId } = req.params;
    const { message } = req.body;
    const userId = req.user.id;
    
    if (!message || message.trim() === '') {
      return res.status(400).json({ error: 'Message cannot be empty' });
    }
    
    // Check if chat_messages table exists
    const checkTableQuery = `
      SELECT COUNT(*) as count FROM information_schema.tables 
      WHERE table_schema = DATABASE() AND table_name = 'chat_messages'
    `;
    
    const [tableCheck] = await db.promise().query(checkTableQuery);
    if (tableCheck[0].count === 0) {
      // Create the table
      const createTableQuery = `
        CREATE TABLE chat_messages (
          id INT AUTO_INCREMENT PRIMARY KEY,
          project_id INT NOT NULL,
          user_id INT NOT NULL,
          message TEXT NOT NULL,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
          FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        )
      `;
      await db.promise().query(createTableQuery);
    }
    
    // Check if user is authorized to post in this project
    const userCheckQuery = `
      SELECT 1 FROM projects WHERE id = ? AND created_by = ?
      UNION
      SELECT 1 FROM project_team WHERE project_id = ? AND user_id = ?
    `;
    
    const [userCheck] = await db.promise().query(userCheckQuery, [
      projectId, 
      userId,
      projectId,
      userId
    ]);
    
    if (userCheck.length === 0) {
      return res.status(403).json({ error: 'You do not have access to this project' });
    }
    
    // Insert message
    const query = `
      INSERT INTO chat_messages (project_id, user_id, message)
      VALUES (?, ?, ?)
    `;
    
    const [result] = await db.promise().query(query, [projectId, userId, message]);
    
    // Get the inserted message with user details
    const getMessageQuery = `
      SELECT 
        cm.id, 
        cm.message, 
        cm.created_at, 
        u.id as user_id, 
        u.name as user_name
      FROM chat_messages cm
      JOIN users u ON cm.user_id = u.id
      WHERE cm.id = ?
    `;
    
    const [messages] = await db.promise().query(getMessageQuery, [result.insertId]);
    
    res.status(201).json(messages[0]);
  } catch (error) {
    console.error('Error sending message:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
