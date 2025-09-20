const express = require('express');
const router = express.Router();
const db = require('../config/database');

const auth = require('../middleware/auth');

// Get all requests sent by the current user
router.get('/requests/sent', auth, async (req, res) => {
  try {
    const userId = req.user.id;
    console.log('Fetching sent requests for user:', userId);
    
    // First check if table exists to prevent errors on initial setup
    const checkTableQuery = `
      SELECT COUNT(*) as count FROM information_schema.tables 
      WHERE table_schema = DATABASE() AND table_name = 'project_requests'
    `;
    const [tableCheck] = await db.promise().query(checkTableQuery);
    console.log('Table check result:', tableCheck);
    
    if (tableCheck[0].count === 0) {
      // Table doesn't exist yet, return empty array
      console.log('project_requests table does not exist');
      return res.json([]);
    }
    
    // Modified query: removed p.sector as it doesn't exist in the projects table
    const query = `
      SELECT 
        pr.id, 
        pr.status, 
        pr.created_at,
        p.id as project_id, 
        p.title, 
        p.description, 
        u.name as creator_name
      FROM project_requests pr
      JOIN projects p ON pr.project_id = p.id
      JOIN users u ON p.created_by = u.id
      WHERE pr.user_id = ?
      ORDER BY pr.created_at DESC
    `;
    
    const [rows] = await db.promise().query(query, [userId]);
    console.log('Sent requests query result:', rows.length, 'rows found');
    
    // Always return an array, even if empty
    res.json(rows || []);
  } catch (error) {
    console.error('Error fetching sent requests:', error);
    // Send error details in development environment
    res.status(500).json({ 
      error: 'Error fetching sent requests', 
      message: error.message 
    });
  }
});

// Get all requests received for projects created by the current user
router.get('/requests/received', auth, async (req, res) => {
  try {
    const userId = req.user.id;
    
    const query = `
      SELECT pr.id, pr.status, pr.created_at, p.title, p.id as project_id, 
             u.name as requester_name, u.id as requester_id, u.email as requester_email
      FROM project_requests pr
      JOIN projects p ON pr.project_id = p.id
      JOIN users u ON pr.user_id = u.id
      WHERE p.created_by = ?
      ORDER BY pr.created_at DESC
    `;
    
    const [rows] = await db.promise().query(query, [userId]);
    res.json(rows);
  } catch (error) {
    console.error('Error fetching received requests:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// Accept a join request
router.post('/requests/:requestId/accept', auth, async (req, res) => {
  try {
    const { requestId } = req.params;
    const userId = req.user.id;
    
    console.log('Accepting request:', requestId, 'by user:', userId);
    
    // First check if the request is for a project owned by the user
    const checkQuery = `
      SELECT pr.id, p.id as project_id, pr.user_id as requester_id
      FROM project_requests pr
      JOIN projects p ON pr.project_id = p.id
      WHERE pr.id = ? AND p.created_by = ?
    `;
    
    const [checkResult] = await db.promise().query(checkQuery, [requestId, userId]);
    console.log('Check result:', checkResult);
    
    if (checkResult.length === 0) {
      return res.status(403).json({ error: 'You are not authorized to accept this request' });
    }
    
    const projectId = checkResult[0].project_id;
    const requesterId = checkResult[0].requester_id;
    
    // Begin transaction
    await db.promise().beginTransaction();
    
    try {
      // Update request status to accepted
      console.log('Updating request status to accepted');
      await db.promise().query(
        'UPDATE project_requests SET status = ? WHERE id = ?',
        ['accepted', requestId]
      );
      
      // First check if project_team table exists
      const checkTableQuery = `
        SELECT COUNT(*) as count FROM information_schema.tables 
        WHERE table_schema = DATABASE() AND table_name = 'project_team'
      `;
      const [tableCheck] = await db.promise().query(checkTableQuery);
      
      // Only try to add the user to the team if the table exists
      if (tableCheck[0].count > 0) {
        // Check if user is already in project team
        const [existingMember] = await db.promise().query(
          'SELECT * FROM project_team WHERE project_id = ? AND user_id = ?',
          [projectId, requesterId]
        );
        
        // Only add to team if not already a member
        if (existingMember.length === 0) {
          console.log('Adding user to project team');
          await db.promise().query(
            'INSERT INTO project_team (project_id, user_id, role, joined_at) VALUES (?, ?, ?, NOW())',
            [projectId, requesterId, 'member']
          );
        }
      } else {
        console.log('project_team table does not exist, skipping team addition');
        // Create the table if needed
        try {
          const createTableQuery = `
            CREATE TABLE project_team (
              id INT AUTO_INCREMENT PRIMARY KEY,
              project_id INT NOT NULL,
              user_id INT NOT NULL,
              role ENUM('owner', 'member') DEFAULT 'member',
              joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
              FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
              FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
              UNIQUE KEY unique_project_user (project_id, user_id)
            )
          `;
          await db.promise().query(createTableQuery);
          console.log('Created project_team table');
          
          // Now add the user to the team
          await db.promise().query(
            'INSERT INTO project_team (project_id, user_id, role, joined_at) VALUES (?, ?, ?, NOW())',
            [projectId, requesterId, 'member']
          );
        } catch (createError) {
          console.error('Error creating project_team table:', createError);
          // We'll continue with the transaction even if table creation fails
        }
      }
      
      // Commit transaction
      await db.promise().commit();
      
      res.json({ message: 'Request accepted successfully' });
    } catch (error) {
      await db.promise().rollback();
      throw error; // Re-throw to be caught by outer catch
    }
  } catch (error) {
    console.error('Error accepting request:', error);
    res.status(500).json({ error: 'Server error', details: error.message });
  }
});

// Reject a join request
router.post('/requests/:requestId/reject', auth, async (req, res) => {
  try {
    const { requestId } = req.params;
    const userId = req.user.id;
    
    console.log('Rejecting request:', requestId, 'by user:', userId);
    
    // Check if the request is for a project owned by the user
    const checkQuery = `
      SELECT pr.id, p.id as project_id
      FROM project_requests pr
      JOIN projects p ON pr.project_id = p.id
      WHERE pr.id = ? AND p.created_by = ?
    `;
    
    const [checkResult] = await db.promise().query(checkQuery, [requestId, userId]);
    console.log('Check result:', checkResult);
    
    if (checkResult.length === 0) {
      return res.status(403).json({ error: 'You are not authorized to reject this request' });
    }
    
    try {
      // Begin transaction
      await db.promise().beginTransaction();
      
      // Update request status to rejected
      console.log('Updating request status to rejected');
      await db.promise().query(
        'UPDATE project_requests SET status = ? WHERE id = ?',
        ['rejected', requestId]
      );
      
      // Commit transaction
      await db.promise().commit();
      
      res.json({ message: 'Request rejected successfully' });
    } catch (error) {
      await db.promise().rollback();
      throw error; // Re-throw to be caught by outer catch
    }
  } catch (error) {
    console.error('Error rejecting request:', error);
    res.status(500).json({ error: 'Server error', details: error.message });
  }
});

// ================== TEAM ROUTES ==================

// Get all teams the current user is a member of
router.get('/my-teams', auth, async (req, res) => {
  try {
    const userId = req.user.id;
    
    const query = `
      SELECT t.*, u.name as creator_name, 
             (SELECT COUNT(*) FROM team_members WHERE team_id = t.id) as member_count,
             tm.role as user_role
      FROM teams t
      JOIN team_members tm ON t.id = tm.team_id
      JOIN users u ON t.created_by = u.id
      WHERE tm.user_id = ?
      ORDER BY t.created_at DESC
    `;
    
    const [rows] = await db.promise().query(query, [userId]);
    res.json(rows);
  } catch (error) {
    console.error('Error fetching user teams:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// Create a new team
router.post('/create', auth, async (req, res) => {
  try {
    const { name, description } = req.body;
    const userId = req.user.id;
    
    // Validate input
    if (!name || name.trim() === '') {
      return res.status(400).json({ error: 'Team name is required' });
    }
    
    // Begin transaction
    await db.promise().beginTransaction();
    
    // Create team
    const createTeamQuery = `
      INSERT INTO teams (name, description, created_by)
      VALUES (?, ?, ?)
    `;
    
    const [teamResult] = await db.promise().query(createTeamQuery, [name, description, userId]);
    const teamId = teamResult.insertId;
    
    // Add creator as team admin
    const addAdminQuery = `
      INSERT INTO team_members (team_id, user_id, role)
      VALUES (?, ?, ?)
    `;
    
    await db.promise().query(addAdminQuery, [teamId, userId, 'admin']);
    
    // Commit transaction
    await db.promise().commit();
    
    res.status(201).json({
      id: teamId,
      name,
      description,
      created_by: userId,
      message: 'Team created successfully'
    });
  } catch (error) {
    await db.promise().rollback();
    console.error('Error creating team:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// Get team details
router.get('/:teamId', auth, async (req, res) => {
  try {
    const { teamId } = req.params;
    const userId = req.user.id;
    
    // First check if user is a member of this team
    const memberCheckQuery = `
      SELECT * FROM team_members
      WHERE team_id = ? AND user_id = ?
    `;
    
    const [memberCheck] = await db.promise().query(memberCheckQuery, [teamId, userId]);
    if (memberCheck.length === 0) {
      return res.status(403).json({ error: 'You are not a member of this team' });
    }
    
    // Get team details
    const teamQuery = `
      SELECT t.*, u.name as creator_name
      FROM teams t
      JOIN users u ON t.created_by = u.id
      WHERE t.id = ?
    `;
    
    const [teamResult] = await db.promise().query(teamQuery, [teamId]);
    if (teamResult.length === 0) {
      return res.status(404).json({ error: 'Team not found' });
    }
    
    // Get team members
    const membersQuery = `
      SELECT tm.role, tm.joined_at, u.id, u.name, u.email
      FROM team_members tm
      JOIN users u ON tm.user_id = u.id
      WHERE tm.team_id = ?
      ORDER BY tm.role ASC, tm.joined_at ASC
    `;
    
    const [membersResult] = await db.promise().query(membersQuery, [teamId]);
    
    // Get team projects
    const projectsQuery = `
      SELECT p.id, p.title, p.description, p.created_at, u.name as owner_name
      FROM team_projects tp
      JOIN projects p ON tp.project_id = p.id
      JOIN users u ON p.created_by = u.id
      WHERE tp.team_id = ?
      ORDER BY p.created_at DESC
    `;
    
    const [projectsResult] = await db.promise().query(projectsQuery, [teamId]);
    
    res.json({
      ...teamResult[0],
      members: membersResult,
      projects: projectsResult
    });
  } catch (error) {
    console.error('Error fetching team details:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// Get all projects the user is a member of or created
router.get('/user/teams', auth, async (req, res) => {
  try {
    const userId = req.user.id;
    console.log('Fetching teams for user:', userId);
    
    // First check if project_team table exists
    const checkTableQuery = `
      SELECT COUNT(*) as count FROM information_schema.tables 
      WHERE table_schema = DATABASE() AND table_name = 'project_team'
    `;
    const [tableCheck] = await db.promise().query(checkTableQuery);
    
    // If table doesn't exist, just fetch projects they've created
    if (tableCheck[0].count === 0) {
      const ownedProjectsQuery = `
        SELECT 
          p.id, p.title, p.description, p.created_at,
          u.name as creator_name, u.id as creator_id,
          'owner' as role,
          p.created_at as joined_at
        FROM projects p
        JOIN users u ON p.created_by = u.id
        WHERE p.created_by = ?
        ORDER BY p.created_at DESC
      `;
      
      const [rows] = await db.promise().query(ownedProjectsQuery, [userId]);
      console.log(`Found ${rows.length} owned projects for user ${userId}`);
      return res.json(rows);
    }
    
    // If table exists, fetch both projects they've joined AND projects they've created
    const combinedQuery = `
      (
        SELECT 
          p.id, p.title, p.description, p.created_at,
          u.name as creator_name, u.id as creator_id,
          pt.role,
          pt.joined_at
        FROM project_team pt
        JOIN projects p ON pt.project_id = p.id
        JOIN users u ON p.created_by = u.id
        WHERE pt.user_id = ?
      )
      UNION
      (
        SELECT 
          p.id, p.title, p.description, p.created_at,
          u.name as creator_name, u.id as creator_id,
          'owner' as role,
          p.created_at as joined_at
        FROM projects p
        JOIN users u ON p.created_by = u.id
        WHERE p.created_by = ?
          AND NOT EXISTS (
            SELECT 1 FROM project_team 
            WHERE project_id = p.id AND user_id = ?
          )
      )
      ORDER BY joined_at DESC
    `;
    
    const [rows] = await db.promise().query(combinedQuery, [userId, userId, userId]);
    console.log(`Found ${rows.length} total teams for user ${userId}`);
    res.json(rows);
  } catch (error) {
    console.error('Error fetching my teams:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;

