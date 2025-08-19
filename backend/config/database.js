const mysql = require('mysql2');
require('dotenv').config();

// Create connection pool for better performance
const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'synapse_db',
  port: process.env.DB_PORT || 3306,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  acquireTimeout: 60000,
  timeout: 60000
});

// Get promise-based connection
const promisePool = pool.promise();

// Test database connection
const testConnection = async () => {
  try {
    const connection = await promisePool.getConnection();
    console.log('✅ Database connected successfully');
    connection.release();
  } catch (error) {
    console.error('❌ Database connection failed:', error.message);
    console.log('💡 Please make sure MySQL is running and the database exists');
    console.log('💡 You can create the database with: CREATE DATABASE synapse;');
    // Don't exit, just log the error
    console.log('⚠️  Server will start but database features may not work');
  }
};

// Initialize database tables
const initializeTables = async () => {
  try {
    const connection = await promisePool.getConnection();
    
    // Users table
    await connection.execute(`
      CREATE TABLE IF NOT EXISTS users (
        id INT PRIMARY KEY AUTO_INCREMENT,
        name VARCHAR(255) NOT NULL,
        email VARCHAR(255) UNIQUE NOT NULL,
        password_hash VARCHAR(255) NOT NULL,
        google_id VARCHAR(255) UNIQUE,
        avatar_url VARCHAR(500),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        is_active BOOLEAN DEFAULT true
      )
    `);

    // User profiles table
    await connection.execute(`
      CREATE TABLE IF NOT EXISTS user_profiles (
        id INT PRIMARY KEY AUTO_INCREMENT,
        user_id INT NOT NULL,
        branch VARCHAR(100),
        year_of_study VARCHAR(20),
        bio TEXT,
        skills JSON,
        github_url VARCHAR(255),
        linkedin_url VARCHAR(255),
        portfolio_url VARCHAR(255),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    `);

    // Projects table
    await connection.execute(`
      CREATE TABLE IF NOT EXISTS projects (
        id INT PRIMARY KEY AUTO_INCREMENT,
        title VARCHAR(255) NOT NULL,
        description TEXT NOT NULL,
        creator_id INT NOT NULL,
        required_skills JSON,
        status ENUM('open', 'in_progress', 'completed', 'archived') DEFAULT 'open',
        visibility ENUM('public', 'private', 'teaser') DEFAULT 'public',
        max_members INT DEFAULT 5,
        current_members INT DEFAULT 1,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (creator_id) REFERENCES users(id) ON DELETE CASCADE
      )
    `);

    // Project members table
    await connection.execute(`
      CREATE TABLE IF NOT EXISTS project_members (
        id INT PRIMARY KEY AUTO_INCREMENT,
        project_id INT NOT NULL,
        user_id INT NOT NULL,
        role ENUM('creator', 'member') DEFAULT 'member',
        status ENUM('pending', 'accepted', 'rejected') DEFAULT 'accepted',
        joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        UNIQUE KEY unique_project_member (project_id, user_id)
      )
    `);

    // Tasks table
    await connection.execute(`
      CREATE TABLE IF NOT EXISTS tasks (
        id INT PRIMARY KEY AUTO_INCREMENT,
        project_id INT NOT NULL,
        title VARCHAR(255) NOT NULL,
        description TEXT,
        assigned_to INT,
        status ENUM('todo', 'in_progress', 'completed') DEFAULT 'todo',
        priority ENUM('low', 'medium', 'high') DEFAULT 'medium',
        due_date DATE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
        FOREIGN KEY (assigned_to) REFERENCES users(id) ON DELETE SET NULL
      )
    `);

    // Messages table
    await connection.execute(`
      CREATE TABLE IF NOT EXISTS messages (
        id INT PRIMARY KEY AUTO_INCREMENT,
        project_id INT NOT NULL,
        sender_id INT NOT NULL,
        content TEXT NOT NULL,
        message_type ENUM('text', 'file', 'system') DEFAULT 'text',
        file_url VARCHAR(500),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
        FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE
      )
    `);

    // Create join_requests table if it doesn't exist
    await connection.execute(`
      CREATE TABLE IF NOT EXISTS join_requests (
        id INT AUTO_INCREMENT PRIMARY KEY,
        project_id INT NOT NULL,
        user_id INT NOT NULL,
        message TEXT,
        status ENUM('pending', 'accepted', 'rejected') DEFAULT 'pending',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        UNIQUE KEY unique_request (project_id, user_id, status)
      )
    `);

    // Create project_todos table
    await connection.execute(`
      CREATE TABLE IF NOT EXISTS project_todos (
        id VARCHAR(36) PRIMARY KEY,
        project_id VARCHAR(36) NOT NULL,
        title VARCHAR(255) NOT NULL,
        description TEXT,
        priority ENUM('low', 'medium', 'high', 'urgent') DEFAULT 'medium',
        status ENUM('pending', 'in_progress', 'completed', 'cancelled') DEFAULT 'pending',
        due_date DATE,
        assigned_to VARCHAR(36),
        created_by VARCHAR(36) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_project_todos_project (project_id),
        INDEX idx_project_todos_assigned (assigned_to),
        INDEX idx_project_todos_status (status)
      )
    `);

    // Create project_files table
    await connection.execute(`
      CREATE TABLE IF NOT EXISTS project_files (
        id VARCHAR(36) PRIMARY KEY,
        project_id VARCHAR(36) NOT NULL,
        file_name VARCHAR(255) NOT NULL,
        file_url TEXT NOT NULL,
        file_size BIGINT,
        file_type VARCHAR(100),
        uploaded_by VARCHAR(36) NOT NULL,
        uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_project_files_project (project_id),
        INDEX idx_project_files_uploaded_by (uploaded_by)
      )
    `);

    // Create project_meetings table
    await connection.execute(`
      CREATE TABLE IF NOT EXISTS project_meetings (
        id VARCHAR(36) PRIMARY KEY,
        project_id VARCHAR(36) NOT NULL,
        title VARCHAR(255) NOT NULL,
        description TEXT,
        meeting_date DATE NOT NULL,
        meeting_time TIME NOT NULL,
        duration INT DEFAULT 60,
        platform VARCHAR(100),
        meeting_url TEXT,
        created_by VARCHAR(36) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_project_meetings_project (project_id),
        INDEX idx_project_meetings_date (meeting_date),
        INDEX idx_project_meetings_created_by (created_by)
      )
    `);

    // Create project_chat table
    await connection.execute(`
      CREATE TABLE IF NOT EXISTS project_chat (
        id VARCHAR(36) PRIMARY KEY,
        project_id VARCHAR(36) NOT NULL,
        user_id VARCHAR(36) NOT NULL,
        message TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_project_chat_project (project_id),
        INDEX idx_project_chat_user (user_id),
        INDEX idx_project_chat_created (created_at)
      )
    `);

    console.log('✅ All tables created successfully');
    connection.release();
    return true;
  } catch (error) {
    console.error('❌ Failed to initialize database tables:', error);
    console.log('⚠️  Server will start but database features may not work');
    return false;
  }
};

module.exports = { pool: promisePool, testConnection, initializeTables };
