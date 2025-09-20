const express = require('express');
const db = require('../config/database');
const auth = require('../middleware/auth');
const router = express.Router();

// Search projects
router.get('/search', auth, (req, res) => {
  const { query } = req.query;
  const userId = req.user.id;
  
  if (!query) {
    return res.status(400).json({ error: 'Search query is required' });
  }

  const searchQuery = `
    SELECT 
      p.*, 
      u.name as creator_name,
      (SELECT 
        CASE 
          WHEN pt.user_id IS NOT NULL THEN 'joined'
          WHEN pr.status = 'pending' THEN 'pending'
          WHEN pr.status = 'accepted' THEN 'joined'
          WHEN pr.status = 'rejected' THEN 'rejected'
          ELSE NULL
        END
      FROM project_requests pr
      LEFT JOIN project_team pt ON pt.project_id = p.id AND pt.user_id = ?
      WHERE pr.project_id = p.id AND pr.user_id = ?
      LIMIT 1) as request_status
    FROM projects p 
    JOIN users u ON p.created_by = u.id
    WHERE p.title LIKE ? OR p.description LIKE ? OR p.requiredSkills LIKE ? OR p.sector LIKE ?
    ORDER BY p.created_at DESC
  `;
  
  const searchParam = `%${query}%`;
  db.query(
    searchQuery, 
    [userId, userId, searchParam, searchParam, searchParam, searchParam], 
    (err, results) => {
      if (err) return res.status(500).json({ error: 'Database error' });
      res.json(results);
    }
  );
});

// Get all projects
router.get('/', auth, (req, res) => {
  const userId = req.user.id;
  
  // Modified query to include request status for the current user
  const query = `
    SELECT 
      p.*, 
      u.name as creator_name,
      (SELECT 
        CASE 
          WHEN pt.user_id IS NOT NULL THEN 'joined'
          WHEN pr.status = 'pending' THEN 'pending'
          WHEN pr.status = 'accepted' THEN 'joined'
          WHEN pr.status = 'rejected' THEN 'rejected'
          ELSE NULL
        END
      FROM project_requests pr
      LEFT JOIN project_team pt ON pt.project_id = p.id AND pt.user_id = ?
      WHERE pr.project_id = p.id AND pr.user_id = ?
      LIMIT 1) as request_status
    FROM projects p 
    JOIN users u ON p.created_by = u.id 
    ORDER BY p.created_at DESC
  `;
  
  db.query(query, [userId, userId], (err, results) => {
    if (err) return res.status(500).json({ error: 'Database error' });
    res.json(results);
  });
});

// Create project
router.post('/', auth, (req, res) => {
  const { title, description } = req.body;
  
  db.query('INSERT INTO projects (title, description, created_by) VALUES (?, ?, ?)',
    [title, description, req.userId], (err, result) => {
      if (err) return res.status(500).json({ error: 'Database error' });
      res.json({ id: result.insertId, title, description });
    });
});

// Request to join project
router.post('/:id/request', auth, (req, res) => {
  const projectId = req.params.id;
  
  // Check if already requested
  db.query('SELECT * FROM project_requests WHERE project_id = ? AND user_id = ?',
    [projectId, req.userId], (err, results) => {
      if (err) return res.status(500).json({ error: 'Database error' });
      if (results.length > 0) return res.status(400).json({ error: 'Already requested' });
      
      db.query('INSERT INTO project_requests (project_id, user_id) VALUES (?, ?)',
        [projectId, req.userId], (err, result) => {
          if (err) return res.status(500).json({ error: 'Database error' });
          res.json({ message: 'Request sent successfully' });
        });
    });
});

// Get project details by ID
router.get('/:projectId', auth, async (req, res) => {
  try {
    const { projectId } = req.params;
    const userId = req.user.id;
    
    console.log('Fetching details for project:', projectId);
    
    // First check if user is authorized to view this project
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
      console.log('User not authorized to view project');
      return res.status(403).json({ error: 'You do not have access to this project' });
    }
    
    // Get project details
    const projectQuery = `
      SELECT p.*, u.name as creator_name
      FROM projects p
      JOIN users u ON p.created_by = u.id
      WHERE p.id = ?
    `;
    
    const [projectResult] = await db.promise().query(projectQuery, [projectId]);
    
    if (projectResult.length === 0) {
      console.log('Project not found');
      return res.status(404).json({ error: 'Project not found' });
    }
    
    // Get project members
    const membersQuery = `
      SELECT 
        pt.user_id as id, 
        pt.role, 
        pt.joined_at,
        u.name,
        u.email
      FROM project_team pt
      JOIN users u ON pt.user_id = u.id
      WHERE pt.project_id = ?
      
      UNION
      
      SELECT 
        p.created_by as id, 
        'owner' as role, 
        p.created_at as joined_at,
        u.name,
        u.email
      FROM projects p
      JOIN users u ON p.created_by = u.id
      WHERE p.id = ? AND p.created_by NOT IN (
        SELECT user_id FROM project_team WHERE project_id = ?
      )
    `;
    
    const [membersResult] = await db.promise().query(membersQuery, [projectId, projectId, projectId]);
    
    const projectDetails = {
      ...projectResult[0],
      members: membersResult
    };
    
    console.log(`Found project with ${membersResult.length} members`);
    res.json(projectDetails);
  } catch (error) {
    console.error('Error fetching project details:', error);
    res.status(500).json({ error: 'Failed to load project details', details: error.message });
  }
});

module.exports = router;
