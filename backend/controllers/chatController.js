const db = require('../config/database');

// Save a message to the database
exports.saveMessage = async (projectId, userId, message) => {
  try {
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
    
    return messages[0];
  } catch (error) {
    console.error('Error saving message:', error);
    throw error;
  }
};

// Get all messages for a project
exports.getProjectMessages = async (projectId) => {
  try {
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
    
    const [messages] = await db.promise().query(query, [projectId]);
    return messages;
  } catch (error) {
    console.error('Error fetching messages:', error);
    throw error;
  }
};
