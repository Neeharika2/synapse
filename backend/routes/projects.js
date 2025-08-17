const express = require('express');
const { pool } = require('../config/database');
const authMiddleware = require('../middleware/auth');

const router = express.Router();

// Get all projects (discovery, my projects, or joined projects)
router.get('/', authMiddleware, async (req, res) => {
  try {
    const { search, skills, status } = req.query;
    let query = `
      SELECT 
        p.id, p.title, p.description, p.required_skills, p.status,
        p.max_members, p.current_members, p.created_at, p.visibility,
        p.creator_id, u.name as creator_name
      FROM projects p
      JOIN users u ON p.creator_id = u.id
    `;
    const params = [];
    let whereAdded = false;

    // Handle different query types
    if (status === 'my_projects') {
      // Get projects created by the current user
      query += ' WHERE p.creator_id = ?';
      params.push(req.userId);
      whereAdded = true;
    } else if (status === 'joined_projects') {
      // Get projects the user has joined but didn't create
      query += ` WHERE p.id IN (
        SELECT project_id FROM project_members 
        WHERE user_id = ? AND status = 'accepted'
      ) AND p.creator_id != ?`;
      params.push(req.userId, req.userId);
      whereAdded = true;
    } else {
      // Public project discovery
      query += ' WHERE p.visibility = "public"';
      whereAdded = true;
      
      if (search) {
        query += ' AND (p.title LIKE ? OR p.description LIKE ?)';

        params.push(`%${search}%`, `%${search}%`);
      }
    }

    // Add skills filter if needed
    if (skills && skills.length > 0) {
      const skillsArray = Array.isArray(skills) ? skills : [skills];
      const skillsPlaceholders = skillsArray.map(() => '?').join(',');
      
      query += whereAdded ? ' AND' : ' WHERE';
      query += ` JSON_OVERLAPS(p.required_skills, JSON_ARRAY(${skillsPlaceholders}))`;
      params.push(...skillsArray);
    }

    query += ' ORDER BY p.created_at DESC LIMIT 50';

    const [projects] = await pool.execute(query, params);

    // Parse required_skills JSON
    projects.forEach(project => {
      if (project.required_skills) {
        try {
          project.required_skills = JSON.parse(project.required_skills);
        } catch (e) {
          project.required_skills = [];
        }
      }
    });

    res.json(projects);
  } catch (error) {
    console.error('Get projects error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Create new project
router.post('/', authMiddleware, async (req, res) => {
  try {
    const { title, description, requiredSkills, maxMembers, visibility } = req.body;

    console.log('📝 Creating project:', { title, description, requiredSkills, maxMembers, visibility });

    if (!title || !description) {
      return res.status(400).json({ error: 'Title and description are required' });
    }

    if (!requiredSkills || requiredSkills.length === 0) {
      return res.status(400).json({ error: 'At least one required skill must be specified' });
    }

    const skillsJson = JSON.stringify(requiredSkills);
    const finalMaxMembers = maxMembers || 5;
    const finalVisibility = visibility || 'public';

    console.log('💾 Inserting into database:', {
      title,
      description,
      creator_id: req.userId,
      required_skills: skillsJson,
      max_members: finalMaxMembers,
      visibility: finalVisibility
    });

    const [result] = await pool.execute(`
      INSERT INTO projects 
      (title, description, creator_id, required_skills, max_members, visibility, current_members)
      VALUES (?, ?, ?, ?, ?, ?, 1)
    `, [title, description, req.userId, skillsJson, finalMaxMembers, finalVisibility]);

    console.log('✅ Project created with ID:', result.insertId);

    // Add creator as first member
    await pool.execute(
      'INSERT INTO project_members (project_id, user_id, role, status) VALUES (?, ?, ?, ?)',

      [result.insertId, req.userId, 'creator', 'accepted']
    );

    console.log('✅ Creator added as project member');

    res.status(201).json({
      success: true,
      message: 'Project created successfully',
      data: {
        projectId: result.insertId,
        title,
        description,
        requiredSkills,
        maxMembers: finalMaxMembers,
        visibility: finalVisibility
      }
    });
  } catch (error) {
    console.error('❌ Create project error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get project details
router.get('/:id', async (req, res) => {
  try {
    const projectId = req.params.id;

    const [projects] = await pool.execute(`
      SELECT 
        p.*,
        u.name as creator_name,
        u.email as creator_email
      FROM projects p
      JOIN users u ON p.creator_id = u.id
      WHERE p.id = ?
    `, [projectId]);

    if (projects.length === 0) {
      return res.status(404).json({ error: 'Project not found' });
    }

    const project = projects[0];
    if (project.required_skills) {
      project.required_skills = JSON.parse(project.required_skills);
    }

    // Get project members
    const [members] = await pool.execute(`
      SELECT 
        u.id, u.name, u.email, u.avatar_url,
        pm.role, pm.status, pm.joined_at
      FROM project_members pm
      JOIN users u ON pm.user_id = u.id
      WHERE pm.project_id = ? AND pm.status = 'accepted'
    `, [projectId]);

    project.members = members;

    res.json(project);
  } catch (error) {
    console.error('Get project details error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get all pending join requests for projects owned by the current user
router.get('/requests', authMiddleware, async (req, res) => {
  try {
    const userId = req.userId;
    
    // Fetch all projects owned by the user
    const [userProjects] = await pool.execute(
      'SELECT id FROM projects WHERE creator_id = ?',
      [userId]
    );
    
    if (userProjects.length === 0) {
      return res.json({ success: true, data: [] });
    }
    
    // Get project IDs
    const projectIds = userProjects.map(project => project.id);
    const placeholders = projectIds.map(() => '?').join(',');
    
    // Fetch all pending join requests for those projects
    const [requests] = await pool.execute(
      `SELECT 
        jr.id, jr.project_id, jr.user_id, jr.message, jr.status, jr.created_at,
        p.title as project_title,
        u.name as user_name, u.email as user_email
      FROM join_requests jr
      JOIN projects p ON jr.project_id = p.id
      JOIN users u ON jr.user_id = u.id
      WHERE jr.project_id IN (${placeholders}) AND jr.status = 'pending'
      ORDER BY jr.created_at DESC`,
      [...projectIds]
    );
    
    console.log(`Found ${requests.length} pending join requests`);
    res.json({ success: true, data: requests });
  } catch (error) {
    console.error('Error fetching join requests:', error);
    res.status(500).json({ 
      success: false, 
      error: 'Failed to fetch join requests' 
    });
  }
});

// Request to join a project
router.post('/:projectId/join', authMiddleware, async (req, res) => {
  try {
    const { projectId } = req.params;
    const userId = req.userId;
    const { message } = req.body;
    
    console.log(`User ${userId} requested to join project ${projectId} with message: ${message}`);
    
    // Check if project exists
    const [projectRows] = await pool.execute(
      'SELECT id, creator_id FROM projects WHERE id = ?',
      [projectId]
    );
    
    if (projectRows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Project not found'
      });
    }
    
    // Check if user is already the creator
    if (projectRows[0].creator_id.toString() === userId.toString()) {
      return res.status(400).json({
        success: false,
        error: 'You cannot join your own project'
      });
    }
    
    // Check if user is already a member
    const [memberRows] = await pool.execute(
      'SELECT id FROM project_members WHERE project_id = ? AND user_id = ? AND status = "accepted"',
      [projectId, userId]
    );
    
    if (memberRows.length > 0) {
      return res.status(400).json({
        success: false,
        error: 'You are already a member of this project'
      });
    }
    
    // Check if user has already sent a pending request
    const [requestRows] = await pool.execute(
      'SELECT id FROM join_requests WHERE project_id = ? AND user_id = ? AND status = "pending"',
      [projectId, userId]
    );
    
    if (requestRows.length > 0) {
      return res.status(400).json({
        success: false,
        error: 'You already have a pending join request for this project'
      });
    }
    
    // Create join request
    const [result] = await pool.execute(
      'INSERT INTO join_requests (project_id, user_id, message, status) VALUES (?, ?, ?, "pending")',
      [projectId, userId, message || null]
    );
    
    console.log(`Join request created with ID: ${result.insertId}`);
    
    res.json({
      success: true,
      message: 'Join request sent successfully',
      data: { requestId: result.insertId }
    });
  } catch (error) {
    console.error('Error sending join request:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to send join request'
    });
  }
});

// Accept or reject a join request
router.post('/:projectId/requests/:requestId/:action', authMiddleware, async (req, res) => {
  try {
    const { projectId, requestId, action } = req.params;
    const userId = req.userId;
    
    if (action !== 'accept' && action !== 'reject') {
      return res.status(400).json({
        success: false,
        error: 'Invalid action. Use "accept" or "reject"'
      });
    }
    
    // Check if user is the project owner
    const [projectRows] = await pool.execute(
      'SELECT creator_id FROM projects WHERE id = ?',
      [projectId]
    );
    
    if (projectRows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Project not found'
      });
    }
    
    if (projectRows[0].creator_id.toString() !== userId.toString()) {
      return res.status(403).json({
        success: false,
        error: 'Only the project creator can manage join requests'
      });
    }
    
    // Get the request details
    const [requestRows] = await pool.execute(
      'SELECT * FROM join_requests WHERE id = ? AND project_id = ? AND status = "pending"',
      [requestId, projectId]
    );
    
    if (requestRows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Join request not found or already processed'
      });
    }
    
    const joinRequest = requestRows[0];
    
    // Begin transaction
    await pool.execute('START TRANSACTION');
    
    // Update request status
    await pool.execute(
      'UPDATE join_requests SET status = ? WHERE id = ?',
      [action === 'accept' ? 'accepted' : 'rejected', requestId]
    );
    
    // If accepting, add user to project members
    if (action === 'accept') {
      // Check if user is already a member (rare edge case)
      const [existingMember] = await pool.execute(
        'SELECT id FROM project_members WHERE project_id = ? AND user_id = ?',
        [projectId, joinRequest.user_id]
      );
      
      if (existingMember.length === 0) {
        await pool.execute(
          'INSERT INTO project_members (project_id, user_id, role, status) VALUES (?, ?, "member", "accepted")',
          [projectId, joinRequest.user_id]
        );
        
        // Update project's current_members count
        await pool.execute(
          'UPDATE projects SET current_members = current_members + 1 WHERE id = ?',
          [projectId]
        );
      }
    }
    
    // Commit transaction
    await pool.execute('COMMIT');
    
    res.json({
      success: true,
      message: action === 'accept' ? 'User added to the project' : 'Request rejected'
    });
  } catch (error) {
    // Rollback transaction on error
    await pool.execute('ROLLBACK');
    console.error(`Error ${req.params.action}ing join request:`, error);
    res.status(500).json({
      success: false,
      error: `Failed to ${req.params.action} join request`
    });
  }
});

// Leave project
router.post('/:projectId/leave', authMiddleware, async (req, res) => {
  try {
    const projectId = req.params.projectId;
    console.log(`👤 User ${req.userId} requesting to leave project ${projectId}`);

    // Check if user is a member of the project
    const [membership] = await pool.execute(`
      SELECT id, role FROM project_members 
      WHERE project_id = ? AND user_id = ? AND status = 'accepted'
    `, [projectId, req.userId]);

    if (membership.length === 0) {
      return res.status(400).json({ success: false, error: 'You are not a member of this project' });
    }

    // Don't allow creator to leave their own project
    if (membership[0].role === 'creator') {
      return res.status(400).json({ 
        success: false,
        error: 'Project creators cannot leave their own projects. Consider archiving the project instead.' 
      });
    }

    console.log(`✅ User ${req.userId} is leaving project ${projectId}`);

    // Remove user from project members
    await pool.execute(`
      DELETE FROM project_members 
      WHERE project_id = ? AND user_id = ?
    `, [projectId, req.userId]);

    // Update current members count
    await pool.execute(`
      UPDATE projects 
      SET current_members = GREATEST(current_members - 1, 1)
      WHERE id = ?
    `, [projectId]);

    // Get updated project details
    const [updatedProjects] = await pool.execute(`
      SELECT 
        p.*,
        u.name as creator_name
      FROM projects p
      JOIN users u ON p.creator_id = u.id
      WHERE p.id = ?
    `, [projectId]);

    if (updatedProjects.length > 0) {
      const project = updatedProjects[0];
      if (project.required_skills) {
        try {
          project.required_skills = JSON.parse(project.required_skills);
        } catch (e) {
          project.required_skills = [];
        }
      }

      console.log(`✅ User ${req.userId} successfully left project ${projectId}`);
      res.json({
        success: true,
        message: 'Left project successfully',
        data: { project }
      });
    } else {
      res.json({
        success: true,
        message: 'Left project successfully'
      });
    }
  } catch (error) {
    console.error('Leave project error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

// Get user's project membership status
router.get('/:projectId/membership', authMiddleware, async (req, res) => {
  try {
    const projectId = req.params.projectId;

    const [membership] = await pool.execute(`
      SELECT role, status, joined_at
      FROM project_members 
      WHERE project_id = ? AND user_id = ?
    `, [projectId, req.userId]);

    if (membership.length === 0) {
      return res.json({
        success: true,
        data: {
          isMember: false,
          role: null,
          status: null,
          canLeave: false
        }
      });
    }

    const member = membership[0];
    const canLeave = member.status === 'accepted' && member.role !== 'creator';

    res.json({
      success: true,
      data: {
        isMember: true,
        role: member.role,
        status: member.status,
        canLeave,
        joinedAt: member.joined_at
      }
    });
  } catch (error) {
    console.error('Get membership error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get all received join requests (requests for projects owned by current user)
router.get('/requests/received', authMiddleware, async (req, res) => {
  try {
    const userId = req.userId;
    
    // Fetch all projects owned by the user
    const [userProjects] = await pool.execute(
      'SELECT id FROM projects WHERE creator_id = ?',
      [userId]
    );
    
    if (userProjects.length === 0) {
      return res.json({ success: true, data: [] });
    }
    
    // Get project IDs
    const projectIds = userProjects.map(project => project.id);
    const placeholders = projectIds.map(() => '?').join(',');
    
    // Fetch all pending join requests for those projects
    const [requests] = await pool.execute(
      `SELECT 
        jr.id, jr.project_id, jr.user_id, jr.message, jr.status, jr.created_at,
        p.title as project_title,
        u.name as user_name, u.email as user_email
      FROM join_requests jr
      JOIN projects p ON jr.project_id = p.id
      JOIN users u ON jr.user_id = u.id
      WHERE jr.project_id IN (${placeholders}) AND jr.status = 'pending'
      ORDER BY jr.created_at DESC`,
      [...projectIds]
    );
    
    console.log(`Found ${requests.length} pending received join requests`);
    res.json({ success: true, data: requests });
  } catch (error) {
    console.error('Error fetching received join requests:', error);
    res.status(500).json({ 
      success: false, 
      error: 'Failed to fetch received join requests' 
    });
  }
});

// Get all sent join requests by current user
router.get('/requests/sent', authMiddleware, async (req, res) => {
  try {
    const userId = req.userId;
    
    // Fetch all join requests sent by the user
    const [requests] = await pool.execute(
      `SELECT 
        jr.id, jr.project_id, jr.user_id, jr.message, jr.status, jr.created_at,
        p.title as project_title,
        u.name as creator_name
      FROM join_requests jr
      JOIN projects p ON jr.project_id = p.id
      JOIN users u ON p.creator_id = u.id
      WHERE jr.user_id = ?
      ORDER BY jr.created_at DESC`,
      [userId]
    );
    
    console.log(`Found ${requests.length} sent join requests`);
    res.json({ success: true, data: requests });
  } catch (error) {
    console.error('Error fetching sent join requests:', error);
    res.status(500).json({ 
      success: false, 
      error: 'Failed to fetch sent join requests' 
    });
  }
});

// Legacy route for backward compatibility
router.get('/requests', authMiddleware, async (req, res) => {
  try {
    // Redirect to received requests endpoint
    const receivedResponse = await fetch(`${req.protocol}://${req.get('host')}/projects/requests/received`, {
      headers: { 'Authorization': req.headers.authorization }
    });
    const receivedData = await receivedResponse.json();
    res.json(receivedData);
  } catch (error) {
    console.error('Error in legacy requests route:', error);
    res.status(500).json({ 
      success: false, 
      error: 'Failed to fetch join requests' 
    });
  }
});

// Cancel a join request
router.delete('/requests/:requestId', authMiddleware, async (req, res) => {
  try {
    const { requestId } = req.params;
    const userId = req.userId;
    
    // Verify the request exists and belongs to the user
    const [requestRows] = await pool.execute(
      'SELECT * FROM join_requests WHERE id = ? AND user_id = ?',
      [requestId, userId]
    );
    
    if (requestRows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Join request not found or you are not authorized to cancel it'
      });
    }
    
    // Delete the request
    await pool.execute(
      'DELETE FROM join_requests WHERE id = ?',
      [requestId]
    );
    
    console.log(`Join request ${requestId} cancelled by user ${userId}`);
    
    res.json({
      success: true,
      message: 'Join request cancelled successfully'
    });
  } catch (error) {
    console.error('Error cancelling join request:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to cancel join request'
    });
  }
});

module.exports = router;
