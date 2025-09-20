const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const db = require('../config/database');
const auth = require('../middleware/auth');

// Ensure uploads directory exists
const uploadDir = path.join(__dirname, '../uploads');
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

// Set up file storage
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, uniqueSuffix + '-' + file.originalname);
  }
});

const upload = multer({ 
  storage,
  limits: {
    fileSize: 10 * 1024 * 1024 // 10MB limit
  }
});

// Get all files for a project
router.get('/:projectId', auth, async (req, res) => {
  try {
    const { projectId } = req.params;
    const userId = req.user.id;
    
    // Check if project_files table exists
    const checkTableQuery = `
      SELECT COUNT(*) as count FROM information_schema.tables 
      WHERE table_schema = DATABASE() AND table_name = 'project_files'
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
    
    // Get all files
    const query = `
      SELECT 
        pf.id, 
        pf.file_name, 
        pf.file_size, 
        pf.file_type, 
        pf.uploaded_at,
        u.id as uploaded_by_id,
        u.name as uploaded_by_name
      FROM project_files pf
      JOIN users u ON pf.user_id = u.id
      WHERE pf.project_id = ?
      ORDER BY pf.uploaded_at DESC
    `;
    
    const [rows] = await db.promise().query(query, [projectId]);
    res.json(rows);
  } catch (error) {
    console.error('Error fetching project files:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// Upload a file to a project
router.post('/:projectId/upload', auth, upload.single('file'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No file uploaded' });
    }
    
    const { projectId } = req.params;
    const userId = req.user.id;
    
    // Check if project_files table exists
    const checkTableQuery = `
      SELECT COUNT(*) as count FROM information_schema.tables 
      WHERE table_schema = DATABASE() AND table_name = 'project_files'
    `;
    
    const [tableCheck] = await db.promise().query(checkTableQuery);
    if (tableCheck[0].count === 0) {
      // Create the table
      const createTableQuery = `
        CREATE TABLE project_files (
          id INT AUTO_INCREMENT PRIMARY KEY,
          project_id INT NOT NULL,
          user_id INT NOT NULL,
          file_name VARCHAR(255) NOT NULL,
          file_size INT NOT NULL,
          file_type VARCHAR(100) NOT NULL,
          file_path VARCHAR(255) NOT NULL,
          uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
          FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        )
      `;
      await db.promise().query(createTableQuery);
    }
    
    // Check if user is authorized to upload to this project
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
      // Delete the uploaded file
      fs.unlinkSync(req.file.path);
      return res.status(403).json({ error: 'You do not have access to this project' });
    }
    
    // Insert file record
    const query = `
      INSERT INTO project_files 
        (project_id, user_id, file_name, file_size, file_type, file_path)
      VALUES (?, ?, ?, ?, ?, ?)
    `;
    
    const [result] = await db.promise().query(query, [
      projectId,
      userId,
      req.file.originalname,
      req.file.size,
      req.file.mimetype,
      req.file.path
    ]);
    
    // Get the uploaded file details
    const getFileQuery = `
      SELECT 
        pf.id, 
        pf.file_name, 
        pf.file_size, 
        pf.file_type, 
        pf.uploaded_at,
        u.id as uploaded_by_id,
        u.name as uploaded_by_name
      FROM project_files pf
      JOIN users u ON pf.user_id = u.id
      WHERE pf.id = ?
    `;
    
    const [files] = await db.promise().query(getFileQuery, [result.insertId]);
    
    res.status(201).json(files[0]);
  } catch (error) {
    console.error('Error uploading file:', error);
    
    // Delete the uploaded file if there was an error
    if (req.file) {
      fs.unlinkSync(req.file.path);
    }
    
    res.status(500).json({ error: 'Server error' });
  }
});

// Download a file
router.get('/:projectId/download/:fileId', auth, async (req, res) => {
  try {
    const { projectId, fileId } = req.params;
    const userId = req.user.id;
    
    // Check if user is authorized to access this project
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
    
    // Get file details
    const query = `
      SELECT *
      FROM project_files
      WHERE id = ? AND project_id = ?
    `;
    
    const [files] = await db.promise().query(query, [fileId, projectId]);
    
    if (files.length === 0) {
      return res.status(404).json({ error: 'File not found' });
    }
    
    const file = files[0];
    const filePath = file.file_path;
    
    if (!fs.existsSync(filePath)) {
      return res.status(404).json({ error: 'File not found on server' });
    }
    
    res.download(filePath, file.file_name);
  } catch (error) {
    console.error('Error downloading file:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
