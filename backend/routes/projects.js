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

    res.json({ success: true, data: projects });
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

// Get projects created by the current user
router.get('/created', authMiddleware, async (req, res) => {
  try {
    const userId = req.userId;
    
    const [projects] = await pool.execute(`
      SELECT 
        p.*,
        u.name as creator_name,
        u.email as creator_email
      FROM projects p
      JOIN users u ON p.creator_id = u.id
      WHERE p.creator_id = ?
      ORDER BY p.created_at DESC
    `, [userId]);

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

    res.json({ success: true, projects: projects });
  } catch (error) {
    console.error('Get created projects error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

// Get projects the user has joined (but didn't create)
router.get('/joined', authMiddleware, async (req, res) => {
  try {
    const userId = req.userId;
    
    const [projects] = await pool.execute(`
      SELECT 
        p.*,
        u.name as creator_name,
        u.email as creator_email
      FROM projects p
      JOIN users u ON p.creator_id = u.id
      JOIN project_members pm ON p.id = pm.project_id
      WHERE pm.user_id = ? AND pm.status = 'accepted' AND p.creator_id != ?
      ORDER BY p.created_at DESC
    `, [userId, userId]);

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

    res.json({ success: true, projects: projects });
  } catch (error) {
    console.error('Get joined projects error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

// Get project details
router.get('/:id', authMiddleware, async (req, res) => {
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
      return res.status(404).json({ success: false, error: 'Project not found' });
    }

    const project = projects[0];
    if (project.required_skills) {
      try {
        project.required_skills = JSON.parse(project.required_skills);
      } catch (e) {
        console.error('Error parsing required_skills JSON:', e);
        project.required_skills = [];
      }
    } else {
      project.required_skills = [];
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

    project.members = members || [];

    // Get pending join requests if user is the project creator
    if (project.creator_id.toString() === req.userId.toString()) {
      const [pendingRequests] = await pool.execute(`
        SELECT 
          jr.id, jr.project_id, jr.user_id, jr.message, jr.status, jr.created_at,
          u.name as user_name, u.email as user_email
        FROM join_requests jr
        JOIN users u ON jr.user_id = u.id
        WHERE jr.project_id = ? AND jr.status = 'pending'
        ORDER BY jr.created_at DESC
      `, [projectId]);
      
      // Log for debugging
      console.log(`Project ${projectId}: Found ${pendingRequests.length} pending requests specifically for this project`);
      
      project.pending_requests = pendingRequests || [];
    } else {
      project.pending_requests = [];
    }

    res.json({ success: true, data: project });
  } catch (error) {
    console.error('Get project details error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
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
  let connection;
  try {
    const { projectId, requestId, action } = req.params;
    const userId = req.userId;
    
    console.log(`🔹 Processing join request ${requestId} for project ${projectId}, action: ${action}, by user ${userId}`);
    
    if (action !== 'accept' && action !== 'reject') {
      return res.status(400).json({
        success: false,
        error: 'Invalid action. Use "accept" or "reject"'
      });
    }

    // Get a connection from the pool for transaction
    connection = await pool.getConnection();
    
    // Check if user is the project owner
    const [projectRows] = await connection.execute(
      'SELECT creator_id FROM projects WHERE id = ?',
      [projectId]
    );
    
    if (projectRows.length === 0) {
      await connection.release();
      return res.status(404).json({
        success: false,
        error: 'Project not found'
      });
    }
    
    console.log(`🔹 Project creator id: ${projectRows[0].creator_id}, Current user id: ${userId}`);
    
    if (projectRows[0].creator_id.toString() !== userId.toString()) {
      await connection.release();
      return res.status(403).json({
        success: false,
        error: 'Only the project creator can manage join requests'
      });
    }
    
    // Get the request details
    console.log(`🔹 Looking for join request with ID ${requestId} in project ${projectId}`);
    const [requestRows] = await connection.execute(
      'SELECT * FROM join_requests WHERE id = ? AND project_id = ? AND status = "pending"',
      [requestId, projectId]
    );
    
    console.log(`🔹 Found ${requestRows.length} matching join requests`);
    
    if (requestRows.length === 0) {
      await connection.release();
      return res.status(404).json({
        success: false,
        error: 'Join request not found or already processed'
      });
    }
    
    const joinRequest = requestRows[0];
    console.log(`🔹 Processing join request from user ${joinRequest.user_id}`);
    
    // Begin transaction
    await connection.beginTransaction();
    
    // Update request status
    await connection.execute(
      'UPDATE join_requests SET status = ? WHERE id = ?',
      [action === 'accept' ? 'accepted' : 'rejected', requestId]
    );
    
    // If accepting, add user to project members
    if (action === 'accept') {
      // Check if user is already a member (rare edge case)
      const [existingMember] = await connection.execute(
        'SELECT id FROM project_members WHERE project_id = ? AND user_id = ?',
        [projectId, joinRequest.user_id]
      );
      
      console.log(`🔹 User already a member? ${existingMember.length > 0 ? 'Yes' : 'No'}`);
      
      if (existingMember.length === 0) {
        await connection.execute(
          'INSERT INTO project_members (project_id, user_id, role, status) VALUES (?, ?, "member", "accepted")',
          [projectId, joinRequest.user_id]
        );
        
        // Update project's current_members count
        await connection.execute(
          'UPDATE projects SET current_members = current_members + 1 WHERE id = ?',
          [projectId]
        );
      }
    }
    
    // Commit transaction
    await connection.commit();
    
    // Get updated project data to return
    const [projectData] = await connection.execute(`
      SELECT 
        p.*,
        u.name as creator_name,
        u.email as creator_email
      FROM projects p
      JOIN users u ON p.creator_id = u.id
      WHERE p.id = ?
    `, [projectId]);
    
    if (projectData.length > 0) {
      // Parse required skills
      if (projectData[0].required_skills) {
        try {
          projectData[0].required_skills = JSON.parse(projectData[0].required_skills);
        } catch (e) {
          projectData[0].required_skills = [];
        }
      }
    }
    
    console.log(`✅ Successfully ${action}ed join request ${requestId}`);
    
    res.json({
      success: true,
      message: action === 'accept' ? 'User added to the project' : 'Request rejected',
      project: projectData.length > 0 ? projectData[0] : null
    });
  } catch (error) {
    console.error(`❌ Error ${req.params.action}ing join request:`, error);
    
    // Rollback transaction on error
    if (connection) {
      try {
        await connection.rollback();
      } catch (rollbackError) {
        console.error('Error during rollback:', rollbackError);
      }
    }
    
    res.status(500).json({
      success: false,
      error: `Failed to ${req.params.action} join request: ${error.message}`
    });
  } finally {
    // Always release the connection
    if (connection) {
      try {
        await connection.release();
      } catch (releaseError) {
        console.error('Error releasing connection:', releaseError);
      }
    }
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
    
    console.log(`🔍 Fetching received join requests for user ${userId}`);
    
    // Fetch all projects owned by the user
    const [userProjects] = await pool.execute(
      'SELECT id, title FROM projects WHERE creator_id = ?',
      [userId]
    );
    
    console.log(`👤 User owns ${userProjects.length} projects`);
    
    if (userProjects.length === 0) {
      return res.json({ success: true, data: [] });
    }
    
    // Get project IDs
    const projectIds = userProjects.map(project => project.id);
    const placeholders = projectIds.map(() => '?').join(',');
    
    console.log(`🔍 Looking for requests in projects: ${userProjects.map(p => `${p.id} (${p.title})`).join(', ')}`);
    
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
    
    // Format the data for the frontend
    const formattedRequests = requests.map(request => ({
      id: request.id,
      project_id: request.project_id,
      user: {
        id: request.user_id,
        name: request.user_name,
        email: request.user_email
      },
      message: request.message,
      requested_at: request.created_at,
      project_title: request.project_title
    }));
    
    // Log each request with its project
    requests.forEach(req => {
      console.log(`📝 Request ID ${req.id} from ${req.user_name} for project: ${req.project_id} - ${req.project_title}`);
    });
    
    console.log(`Found ${formattedRequests.length} pending received join requests`);
    res.json({ success: true, data: formattedRequests });
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
    
    // Format the data for the frontend
    const formattedRequests = requests.map(request => ({
      id: request.id,
      project_id: request.project_id,
      user: {
        id: request.user_id,
        name: 'You', // Since this is the current user
        email: 'current@user.com'
      },
      message: request.message,
      requested_at: request.created_at,
      project_title: request.project_title,
      creator_name: request.creator_name
    }));
    
    console.log(`Found ${formattedRequests.length} sent join requests`);
    res.json({ success: true, data: formattedRequests });
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

// Get join requests for a specific project (for project dashboard)
router.get('/:projectId/requests', authMiddleware, async (req, res) => {
  try {
    const { projectId } = req.params;
    const userId = req.userId;
    
    // Check if user is the creator of the project
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
    
    if (projectRows[0].creator_id !== userId) {
      return res.status(403).json({
        success: false,
        error: 'Only project creators can view join requests'
      });
    }
    
    // Fetch pending join requests for this project
    const [requests] = await pool.execute(
      `SELECT 
        jr.id, jr.project_id, jr.user_id, jr.message, jr.status, jr.created_at,
        u.name as user_name, u.email as user_email
      FROM join_requests jr
      JOIN users u ON jr.user_id = u.id
      WHERE jr.project_id = ? AND jr.status = 'pending'
      ORDER BY jr.created_at DESC`,
      [projectId]
    );
    
    // Format the data for the frontend
    const formattedRequests = requests.map(request => ({
      id: request.id,
      project_id: request.project_id,
      user: {
        id: request.user_id,
        name: request.user_name,
        email: request.user_email
      },
      message: request.message,
      requested_at: request.created_at
    }));
    
    console.log(`Found ${formattedRequests.length} pending join requests for project ${projectId}`);
    res.json({ success: true, data: formattedRequests });
  } catch (error) {
    console.error('Error fetching project join requests:', error);
    res.status(500).json({ 
      success: false, 
      error: 'Failed to fetch project join requests' 
    });
  }
});

// ===== CHAT MANAGEMENT =====

// Get chat history for a project
router.get('/:projectId/chat', authMiddleware, async (req, res) => {
  try {
    const { projectId } = req.params;
    const userId = req.userId;
    
    // Check if user is a member of the project
    const [membership] = await pool.execute(
      'SELECT * FROM project_members WHERE project_id = ? AND user_id = ? AND status = "accepted"',
      [projectId, userId]
    );
    
    if (membership.length === 0) {
      return res.status(403).json({
        success: false,
        error: 'You must be a member of this project to view chat'
      });
    }
    
    const [messages] = await pool.execute(`
      SELECT 
        c.*,
        u.name as user_name,
        u.email as user_email
      FROM project_chat c
      JOIN users u ON c.user_id = u.id
      WHERE c.project_id = ?
      ORDER BY c.created_at ASC
      LIMIT 100
    `, [projectId]);
    
    res.json({ success: true, data: messages });
  } catch (error) {
    console.error('Error fetching chat history:', error);
    res.status(500).json({ success: false, error: 'Failed to fetch chat history' });
  }
});

// Save chat message to database (for persistence)
router.post('/:projectId/chat', authMiddleware, async (req, res) => {
  try {
    const { projectId } = req.params;
    const { message } = req.body;
    const userId = req.userId;
    
    // Check if user is a member of the project
    const [membership] = await pool.execute(
      'SELECT * FROM project_members WHERE project_id = ? AND user_id = ? AND status = "accepted"',
      [projectId, userId]
    );
    
    if (membership.length === 0) {
      return res.status(403).json({
        success: false,
        error: 'You must be a member of this project to send messages'
      });
    }
    
    const [result] = await pool.execute(`
      INSERT INTO project_chat 
      (project_id, user_id, message)
      VALUES (?, ?, ?)
    `, [projectId, userId, message]);
    
    // Get the saved message
    const [savedMessage] = await pool.execute(`
      SELECT 
        c.*,
        u.name as user_name,
        u.email as user_email
      FROM project_chat c
      JOIN users u ON c.user_id = u.id
      WHERE c.id = ?
    `, [result.insertId]);
    
    res.status(201).json({ success: true, data: savedMessage[0] });
  } catch (error) {
    console.error('Error saving chat message:', error);
    res.status(500).json({ success: false, error: 'Failed to save message' });
  }
});

// ===== TODO MANAGEMENT =====

// Get all todos for a project
router.get('/:projectId/todos', authMiddleware, async (req, res) => {
  try {
    const { projectId } = req.params;
    const userId = req.userId;
    
    // Check if user is a member of the project
    const [membership] = await pool.execute(
      'SELECT * FROM project_members WHERE project_id = ? AND user_id = ? AND status = "accepted"',
      [projectId, userId]
    );
    
    if (membership.length === 0) {
      return res.status(403).json({
        success: false,
        error: 'You must be a member of this project to view todos'
      });
    }
    
    const [todos] = await pool.execute(`
      SELECT 
        t.*,
        u.name as assigned_to_name,
        u.email as assigned_to_email
      FROM project_todos t
      LEFT JOIN users u ON t.assigned_to = u.id
      WHERE t.project_id = ?
      ORDER BY t.priority DESC, t.due_date ASC, t.created_at DESC
    `, [projectId]);
    
    res.json({ success: true, data: todos });
  } catch (error) {
    console.error('Error fetching project todos:', error);
    res.status(500).json({ success: false, error: 'Failed to fetch todos' });
  }
});

// Create a new todo
router.post('/:projectId/todos', authMiddleware, async (req, res) => {
  try {
    const { projectId } = req.params;
    const { title, description, priority, dueDate, assignedTo } = req.body;
    const userId = req.userId;
    
    // Check if user is a member of the project
    const [membership] = await pool.execute(
      'SELECT * FROM project_members WHERE project_id = ? AND user_id = ? AND status = "accepted"',
      [projectId, userId]
    );
    
    if (membership.length === 0) {
      return res.status(403).json({
        success: false,
        error: 'You must be a member of this project to create todos'
      });
    }
    
    const [result] = await pool.execute(`
      INSERT INTO project_todos 
      (project_id, title, description, priority, due_date, assigned_to, created_by, status)
      VALUES (?, ?, ?, ?, ?, ?, ?, 'pending')
    `, [projectId, title, description, priority || 'medium', dueDate, assignedTo, userId]);
    
    // Get the created todo
    const [newTodo] = await pool.execute(`
      SELECT 
        t.*,
        u.name as assigned_to_name,
        u.email as assigned_to_email
      FROM project_todos t
      LEFT JOIN users u ON t.assigned_to = u.id
      WHERE t.id = ?
    `, [result.insertId]);
    
    res.status(201).json({ success: true, data: newTodo[0] });
  } catch (error) {
    console.error('Error creating todo:', error);
    res.status(500).json({ success: false, error: 'Failed to create todo' });
  }
});

// Update a todo
router.put('/:projectId/todos/:todoId', authMiddleware, async (req, res) => {
  try {
    const { projectId, todoId } = req.params;
    const { title, description, priority, dueDate, assignedTo, status } = req.body;
    const userId = req.userId;
    
    // Check if user is a member of the project
    const [membership] = await pool.execute(
      'SELECT * FROM project_members WHERE project_id = ? AND user_id = ? AND status = "accepted"',
      [projectId, userId]
    );
    
    if (membership.length === 0) {
      return res.status(403).json({
        success: false,
        error: 'You must be a member of this project to update todos'
      });
    }
    
    await pool.execute(`
      UPDATE project_todos 
      SET title = ?, description = ?, priority = ?, due_date = ?, assigned_to = ?, status = ?, updated_at = NOW()
      WHERE id = ? AND project_id = ?
    `, [title, description, priority, dueDate, assignedTo, status, todoId, projectId]);
    
    // Get the updated todo
    const [updatedTodo] = await pool.execute(`
      SELECT 
        t.*,
        u.name as assigned_to_name,
        u.email as assigned_to_email
      FROM project_todos t
      LEFT JOIN users u ON t.assigned_to = u.id
      WHERE t.id = ?
    `, [todoId]);
    
    res.json({ success: true, data: updatedTodo[0] });
  } catch (error) {
    console.error('Error updating todo:', error);
    res.status(500).json({ success: false, error: 'Failed to update todo' });
  }
});

// Delete a todo
router.delete('/:projectId/todos/:todoId', authMiddleware, async (req, res) => {
  try {
    const { projectId, todoId } = req.params;
    const userId = req.userId;
    
    // Check if user is a member of the project
    const [membership] = await pool.execute(
      'SELECT * FROM project_members WHERE project_id = ? AND user_id = ? AND status = "accepted"',
      [projectId, userId]
    );
    
    if (membership.length === 0) {
      return res.status(403).json({
        success: false,
        error: 'You must be a member of this project to delete todos'
      });
    }
    
    await pool.execute(
      'DELETE FROM project_todos WHERE id = ? AND project_id = ?',
      [todoId, projectId]
    );
    
    res.json({ success: true, message: 'Todo deleted successfully' });
  } catch (error) {
    console.error('Error deleting todo:', error);
    res.status(500).json({ success: false, error: 'Failed to delete todo' });
  }
});

// ===== FILE MANAGEMENT =====

// Get all files for a project
router.get('/:projectId/files', authMiddleware, async (req, res) => {
  try {
    const { projectId } = req.params;
    const userId = req.userId;
    
    // Check if user is a member of the project
    const [membership] = await pool.execute(
      'SELECT * FROM project_members WHERE project_id = ? AND user_id = ? AND status = "accepted"',
      [projectId, userId]
    );
    
    if (membership.length === 0) {
      return res.status(403).json({
        success: false,
        error: 'You must be a member of this project to view files'
      });
    }
    
    const [files] = await pool.execute(`
      SELECT 
        f.*,
        u.name as uploaded_by_name,
        u.email as uploaded_by_email
      FROM project_files f
      JOIN users u ON f.uploaded_by = u.id
      WHERE f.project_id = ?
      ORDER BY f.uploaded_at DESC
    `, [projectId]);
    
    res.json({ success: true, data: files });
  } catch (error) {
    console.error('Error fetching project files:', error);
    res.status(500).json({ success: false, error: 'Failed to fetch files' });
  }
});

// Upload a file (placeholder - actual file upload will be implemented with multer)
router.post('/:projectId/files', authMiddleware, async (req, res) => {
  try {
    const { projectId } = req.params;
    const { fileName, fileUrl, fileSize, fileType } = req.body;
    const userId = req.userId;
    
    // Check if user is a member of the project
    const [membership] = await pool.execute(
      'SELECT * FROM project_members WHERE project_id = ? AND user_id = ? AND status = "accepted"',
      [projectId, userId]
    );
    
    if (membership.length === 0) {
      return res.status(403).json({
        success: false,
        error: 'You must be a member of this project to upload files'
      });
    }
    
    const [result] = await pool.execute(`
      INSERT INTO project_files 
      (project_id, file_name, file_url, file_size, file_type, uploaded_by)
      VALUES (?, ?, ?, ?, ?, ?)
    `, [projectId, fileName, fileUrl, fileSize, fileType, userId]);
    
    // Get the uploaded file
    const [newFile] = await pool.execute(`
      SELECT 
        f.*,
        u.name as uploaded_by_name,
        u.email as uploaded_by_email
      FROM project_files f
      JOIN users u ON f.uploaded_by = u.id
      WHERE f.id = ?
    `, [result.insertId]);
    
    res.status(201).json({ success: true, data: newFile[0] });
  } catch (error) {
    console.error('Error uploading file:', error);
    res.status(500).json({ success: false, error: 'Failed to upload file' });
  }
});

// Delete a file
router.delete('/:projectId/files/:fileId', authMiddleware, async (req, res) => {
  try {
    const { projectId, fileId } = req.params;
    const userId = req.userId;
    
    // Check if user is a member of the project
    const [membership] = await pool.execute(
      'SELECT * FROM project_members WHERE project_id = ? AND user_id = ? AND status = "accepted"',
      [projectId, userId]
    );
    
    if (membership.length === 0) {
      return res.status(403).json({
        success: false,
        error: 'You must be a member of this project to delete files'
      });
    }
    
    await pool.execute(
      'DELETE FROM project_files WHERE id = ? AND project_id = ?',
      [fileId, projectId]
    );
    
    res.json({ success: true, message: 'File deleted successfully' });
  } catch (error) {
    console.error('Error deleting file:', error);
    res.status(500).json({ success: false, error: 'Failed to delete file' });
  }
});

// ===== MEETING SCHEDULER =====

// Get all meetings for a project
router.get('/:projectId/meetings', authMiddleware, async (req, res) => {
  try {
    const { projectId } = req.params;
    const userId = req.userId;
    
    // Check if user is a member of the project
    const [membership] = await pool.execute(
      'SELECT * FROM project_members WHERE project_id = ? AND user_id = ? AND status = "accepted"',
      [projectId, userId]
    );
    
    if (membership.length === 0) {
      return res.status(403).json({
        success: false,
        error: 'You must be a member of this project to view meetings'
      });
    }
    
    const [meetings] = await pool.execute(`
      SELECT 
        m.*,
        u.name as created_by_name,
        u.email as created_by_email
      FROM project_meetings m
      JOIN users u ON m.created_by = u.id
      WHERE m.project_id = ?
      ORDER BY m.meeting_date ASC, m.meeting_time ASC
    `, [projectId]);
    
    res.json({ success: true, data: meetings });
  } catch (error) {
    console.error('Error fetching project meetings:', error);
    res.status(500).json({ success: false, error: 'Failed to fetch meetings' });
  }
});

// Create a new meeting
router.post('/:projectId/meetings', authMiddleware, async (req, res) => {
  try {
    const { projectId } = req.params;
    const { title, description, meetingDate, meetingTime, duration, platform, meetingUrl } = req.body;
    const userId = req.userId;
    
    // Check if user is a member of the project
    const [membership] = await pool.execute(
      'SELECT * FROM project_members WHERE project_id = ? AND user_id = ? AND status = "accepted"',
      [projectId, userId]
    );
    
    if (membership.length === 0) {
      return res.status(403).json({
        success: false,
        error: 'You must be a member of this project to create meetings'
      });
    }
    
    const [result] = await pool.execute(`
      INSERT INTO project_meetings 
      (project_id, title, description, meeting_date, meeting_time, duration, platform, meeting_url, created_by)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    `, [projectId, title, description, meetingDate, meetingTime, duration, platform, meetingUrl, userId]);
    
    // Get the created meeting
    const [newMeeting] = await pool.execute(`
      SELECT 
        m.*,
        u.name as created_by_name,
        u.email as created_by_email
      FROM project_meetings m
      JOIN users u ON m.created_by = u.id
      WHERE m.id = ?
    `, [result.insertId]);
    
    res.status(201).json({ success: true, data: newMeeting[0] });
  } catch (error) {
    console.error('Error creating meeting:', error);
    res.status(500).json({ success: false, error: 'Failed to create meeting' });
  }
});

// Update a meeting
router.put('/:projectId/meetings/:meetingId', authMiddleware, async (req, res) => {
  try {
    const { projectId, meetingId } = req.params;
    const { title, description, meetingDate, meetingTime, duration, platform, meetingUrl } = req.body;
    const userId = req.userId;
    
    // Check if user is a member of the project
    const [membership] = await pool.execute(
      'SELECT * FROM project_members WHERE project_id = ? AND user_id = ? AND status = "accepted"',
      [projectId, userId]
    );
    
    if (membership.length === 0) {
      return res.status(403).json({
        success: false,
        error: 'You must be a member of this project to update meetings'
      });
    }
    
    await pool.execute(`
      UPDATE project_meetings 
      SET title = ?, description = ?, meeting_date = ?, meeting_time = ?, duration = ?, platform = ?, meeting_url = ?, updated_at = NOW()
      WHERE id = ? AND project_id = ?
    `, [title, description, meetingDate, meetingTime, duration, platform, meetingUrl, meetingId, projectId]);
    
    // Get the updated meeting
    const [updatedMeeting] = await pool.execute(`
      SELECT 
        m.*,
        u.name as created_by_name,
        u.email as created_by_email
      FROM project_meetings m
      JOIN users u ON m.created_by = u.id
      WHERE m.id = ?
    `, [meetingId]);
    
    res.json({ success: true, data: updatedMeeting[0] });
  } catch (error) {
    console.error('Error updating meeting:', error);
    res.status(500).json({ success: false, error: 'Failed to update meeting' });
  }
});

// Delete a meeting
router.delete('/:projectId/meetings/:meetingId', authMiddleware, async (req, res) => {
  try {
    const { projectId, meetingId } = req.params;
    const userId = req.userId;
    
    // Check if user is a member of the project
    const [membership] = await pool.execute(
      'SELECT * FROM project_members WHERE project_id = ? AND user_id = ? AND status = "accepted"',
      [projectId, userId]
    );
    
    if (membership.length === 0) {
      return res.status(403).json({
        success: false,
        error: 'You must be a member of this project to delete meetings'
      });
    }
    
    await pool.execute(
      'DELETE FROM project_meetings WHERE id = ? AND project_id = ?',
      [meetingId, projectId]
    );
    
    res.json({ success: true, message: 'Meeting deleted successfully' });
  } catch (error) {
    console.error('Error deleting meeting:', error);
    res.status(500).json({ success: false, error: 'Failed to delete meeting' });
  }
});

module.exports = router;
