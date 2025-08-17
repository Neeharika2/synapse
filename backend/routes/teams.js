const express = require('express');
const { pool } = require('../config/database');
const authMiddleware = require('../middleware/auth');

const router = express.Router();

// Get team members for a project
router.get('/:projectId/members', authMiddleware, async (req, res) => {
  try {
    const projectId = req.params.projectId;

    // Verify user is member of the project
    const [membership] = await pool.execute(`
      SELECT id FROM project_members 
      WHERE project_id = ? AND user_id = ? AND status = 'accepted'
    `, [projectId, req.userId]);

    if (membership.length === 0) {
      return res.status(403).json({ error: 'Access denied. You are not a member of this project.' });
    }

    // Get all team members
    const [members] = await pool.execute(`
      SELECT 
        u.id, u.name, u.email, u.avatar_url,
        pm.role, pm.status, pm.joined_at,
        up.skills, up.branch, up.year_of_study
      FROM project_members pm
      JOIN users u ON pm.user_id = u.id
      LEFT JOIN user_profiles up ON u.id = up.user_id
      WHERE pm.project_id = ? AND pm.status = 'accepted'
      ORDER BY 
        CASE pm.role 
          WHEN 'creator' THEN 1 
          ELSE 2 
        END,
        pm.joined_at
    `, [projectId]);

    // Parse skills JSON for each member
    members.forEach(member => {
      if (member.skills) {
        member.skills = JSON.parse(member.skills);
      }
    });

    res.json({ members });
  } catch (error) {
    console.error('Get team members error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get team chat messages
router.get('/:projectId/messages', authMiddleware, async (req, res) => {
  try {
    const projectId = req.params.projectId;
    const { limit = 50, offset = 0 } = req.query;

    // Verify user is member of the project
    const [membership] = await pool.execute(`
      SELECT id FROM project_members 
      WHERE project_id = ? AND user_id = ? AND status = 'accepted'
    `, [projectId, req.userId]);

    if (membership.length === 0) {
      return res.status(403).json({ error: 'Access denied' });
    }

    // Get chat messages
    const [messages] = await pool.execute(`
      SELECT 
        m.id, m.content, m.message_type, m.file_url, m.created_at,
        u.id as sender_id, u.name as sender_name, u.avatar_url as sender_avatar
      FROM messages m
      JOIN users u ON m.sender_id = u.id
      WHERE m.project_id = ?
      ORDER BY m.created_at DESC
      LIMIT ? OFFSET ?
    `, [projectId, parseInt(limit), parseInt(offset)]);

    res.json({ messages: messages.reverse() });
  } catch (error) {
    console.error('Get messages error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Send team chat message
router.post('/:projectId/messages', authMiddleware, async (req, res) => {
  try {
    const projectId = req.params.projectId;
    const { content, messageType = 'text', fileUrl } = req.body;

    if (!content && !fileUrl) {
      return res.status(400).json({ error: 'Message content or file is required' });
    }

    // Verify user is member of the project
    const [membership] = await pool.execute(`
      SELECT id FROM project_members 
      WHERE project_id = ? AND user_id = ? AND status = 'accepted'
    `, [projectId, req.userId]);

    if (membership.length === 0) {
      return res.status(403).json({ error: 'Access denied' });
    }

    // Insert message
    const [result] = await pool.execute(`
      INSERT INTO messages (project_id, sender_id, content, message_type, file_url)
      VALUES (?, ?, ?, ?, ?)
    `, [projectId, req.userId, content, messageType, fileUrl]);

    // Get the created message with sender info
    const [newMessage] = await pool.execute(`
      SELECT 
        m.id, m.content, m.message_type, m.file_url, m.created_at,
        u.id as sender_id, u.name as sender_name, u.avatar_url as sender_avatar
      FROM messages m
      JOIN users u ON m.sender_id = u.id
      WHERE m.id = ?
    `, [result.insertId]);

    res.status(201).json({ 
      message: 'Message sent successfully',
      data: newMessage[0]
    });
  } catch (error) {
    console.error('Send message error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get project tasks
router.get('/:projectId/tasks', authMiddleware, async (req, res) => {
  try {
    const projectId = req.params.projectId;

    // Verify user is member of the project
    const [membership] = await pool.execute(`
      SELECT id FROM project_members 
      WHERE project_id = ? AND user_id = ? AND status = 'accepted'
    `, [projectId, req.userId]);

    if (membership.length === 0) {
      return res.status(403).json({ error: 'Access denied' });
    }

    // Get tasks grouped by status
    const [tasks] = await pool.execute(`
      SELECT 
        t.id, t.title, t.description, t.status, t.priority, t.due_date, t.created_at,
        u.id as assigned_to_id, u.name as assigned_to_name
      FROM tasks t
      LEFT JOIN users u ON t.assigned_to = u.id
      WHERE t.project_id = ?
      ORDER BY 
        CASE t.status 
          WHEN 'todo' THEN 1 
          WHEN 'in_progress' THEN 2 
          WHEN 'completed' THEN 3 
        END,
        t.created_at DESC
    `, [projectId]);

    // Group tasks by status
    const tasksByStatus = {
      todo: tasks.filter(task => task.status === 'todo'),
      in_progress: tasks.filter(task => task.status === 'in_progress'),
      completed: tasks.filter(task => task.status === 'completed')
    };

    res.json({ tasks: tasksByStatus });
  } catch (error) {
    console.error('Get tasks error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Create new task
router.post('/:projectId/tasks', authMiddleware, async (req, res) => {
  try {
    const projectId = req.params.projectId;
    const { title, description, assignedTo, priority = 'medium', dueDate } = req.body;

    if (!title) {
      return res.status(400).json({ error: 'Task title is required' });
    }

    // Verify user is member of the project
    const [membership] = await pool.execute(`
      SELECT role FROM project_members 
      WHERE project_id = ? AND user_id = ? AND status = 'accepted'
    `, [projectId, req.userId]);

    if (membership.length === 0) {
      return res.status(403).json({ error: 'Access denied' });
    }

    // Insert task
    const [result] = await pool.execute(`
      INSERT INTO tasks (project_id, title, description, assigned_to, priority, due_date)
      VALUES (?, ?, ?, ?, ?, ?)
    `, [projectId, title, description, assignedTo, priority, dueDate]);

    res.status(201).json({ 
      message: 'Task created successfully',
      taskId: result.insertId
    });
  } catch (error) {
    console.error('Create task error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update task status
router.patch('/:projectId/tasks/:taskId', authMiddleware, async (req, res) => {
  try {
    const { projectId, taskId } = req.params;
    const { status, title, description, assignedTo, priority, dueDate } = req.body;

    // Verify user is member of the project
    const [membership] = await pool.execute(`
      SELECT id FROM project_members 
      WHERE project_id = ? AND user_id = ? AND status = 'accepted'
    `, [projectId, req.userId]);

    if (membership.length === 0) {
      return res.status(403).json({ error: 'Access denied' });
    }

    // Build update query dynamically
    const updates = [];
    const values = [];

    if (status) { updates.push('status = ?'); values.push(status); }
    if (title) { updates.push('title = ?'); values.push(title); }
    if (description !== undefined) { updates.push('description = ?'); values.push(description); }
    if (assignedTo !== undefined) { updates.push('assigned_to = ?'); values.push(assignedTo); }
    if (priority) { updates.push('priority = ?'); values.push(priority); }
    if (dueDate !== undefined) { updates.push('due_date = ?'); values.push(dueDate); }

    if (updates.length === 0) {
      return res.status(400).json({ error: 'No fields to update' });
    }

    values.push(taskId, projectId);

    await pool.execute(`
      UPDATE tasks 
      SET ${updates.join(', ')}, updated_at = CURRENT_TIMESTAMP
      WHERE id = ? AND project_id = ?
    `, values);

    res.json({ message: 'Task updated successfully' });
  } catch (error) {
    console.error('Update task error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Join project request
router.post('/:projectId/join', authMiddleware, async (req, res) => {
  try {
    const projectId = req.params.projectId;

    // Check if project exists and is open
    const [projects] = await pool.execute(`
      SELECT id, current_members, max_members, status 
      FROM projects 
      WHERE id = ?
    `, [projectId]);

    if (projects.length === 0) {
      return res.status(404).json({ error: 'Project not found' });
    }

    const project = projects[0];

    if (project.status !== 'open') {
      return res.status(400).json({ error: 'Project is not accepting new members' });
    }

    if (project.current_members >= project.max_members) {
      return res.status(400).json({ error: 'Project is full' });
    }

    // Check if user is already a member or has pending request
    const [existingMembership] = await pool.execute(`
      SELECT status FROM project_members 
      WHERE project_id = ? AND user_id = ?
    `, [projectId, req.userId]);

    if (existingMembership.length > 0) {
      const status = existingMembership[0].status;
      if (status === 'accepted') {
        return res.status(400).json({ error: 'You are already a member of this project' });
      } else if (status === 'pending') {
        return res.status(400).json({ error: 'You already have a pending request for this project' });
      }
    }

    // Create join request
    await pool.execute(`
      INSERT INTO project_members (project_id, user_id, status)
      VALUES (?, ?, 'pending')
      ON DUPLICATE KEY UPDATE status = 'pending'
    `, [projectId, req.userId]);

    res.status(201).json({ message: 'Join request sent successfully' });
  } catch (error) {
    console.error('Join project error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Accept/Reject join request (for project creators)
router.patch('/:projectId/requests/:userId', authMiddleware, async (req, res) => {
  try {
    const { projectId, userId } = req.params;
    const { action } = req.body; // 'accept' or 'reject'

    if (!['accept', 'reject'].includes(action)) {
      return res.status(400).json({ error: 'Action must be accept or reject' });
    }

    // Verify user is project creator
    const [projects] = await pool.execute(`
      SELECT creator_id, current_members, max_members 
      FROM projects 
      WHERE id = ?
    `, [projectId]);

    if (projects.length === 0) {
      return res.status(404).json({ error: 'Project not found' });
    }

    const project = projects[0];

    if (project.creator_id !== req.userId) {
      return res.status(403).json({ error: 'Only project creator can manage requests' });
    }

    if (action === 'accept') {
      if (project.current_members >= project.max_members) {
        return res.status(400).json({ error: 'Project is full' });
      }

      // Accept the request
      await pool.execute(`
        UPDATE project_members 
        SET status = 'accepted' 
        WHERE project_id = ? AND user_id = ? AND status = 'pending'
      `, [projectId, userId]);

      // Update current members count
      await pool.execute(`
        UPDATE projects 
        SET current_members = current_members + 1 
        WHERE id = ?
      `, [projectId]);

      res.json({ message: 'Request accepted successfully' });
    } else {
      // Reject the request
      await pool.execute(`
        UPDATE project_members 
        SET status = 'rejected' 
        WHERE project_id = ? AND user_id = ? AND status = 'pending'
      `, [projectId, userId]);

      res.json({ message: 'Request rejected successfully' });
    }
  } catch (error) {
    console.error('Handle request error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
