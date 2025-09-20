const express = require('express');
const router = express.Router();
const db = require('../config/database');
const auth = require('../middleware/auth');

// Get all tasks for a project
router.get('/:projectId', auth, async (req, res) => {
  try {
    const { projectId } = req.params;
    const userId = req.user.id;
    
    // Check if project_tasks table exists
    const checkTableQuery = `
      SELECT COUNT(*) as count FROM information_schema.tables 
      WHERE table_schema = DATABASE() AND table_name = 'project_tasks'
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
    
    // Get all tasks
    const query = `
      SELECT 
        t.id, 
        t.title, 
        t.description, 
        t.status,
        t.due_date,
        t.created_at,
        creator.id as creator_id,
        creator.name as creator_name,
        assignee.id as assignee_id,
        assignee.name as assignee_name
      FROM project_tasks t
      JOIN users creator ON t.created_by = creator.id
      LEFT JOIN users assignee ON t.assigned_to = assignee.id
      WHERE t.project_id = ?
      ORDER BY t.status, t.created_at DESC
    `;
    
    const [rows] = await db.promise().query(query, [projectId]);
    res.json(rows);
  } catch (error) {
    console.error('Error fetching project tasks:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// Create a new task
router.post('/:projectId', auth, async (req, res) => {
  try {
    const { projectId } = req.params;
    const { title, description, status, assignedTo, dueDate } = req.body;
    const userId = req.user.id;
    
    if (!title || title.trim() === '') {
      return res.status(400).json({ error: 'Task title is required' });
    }
    
    // Check if project_tasks table exists
    const checkTableQuery = `
      SELECT COUNT(*) as count FROM information_schema.tables 
      WHERE table_schema = DATABASE() AND table_name = 'project_tasks'
    `;
    
    const [tableCheck] = await db.promise().query(checkTableQuery);
    if (tableCheck[0].count === 0) {
      // Create the table
      const createTableQuery = `
        CREATE TABLE project_tasks (
          id INT AUTO_INCREMENT PRIMARY KEY,
          project_id INT NOT NULL,
          title VARCHAR(255) NOT NULL,
          description TEXT,
          status ENUM('todo', 'in_progress', 'done') DEFAULT 'todo',
          assigned_to INT,
          created_by INT NOT NULL,
          due_date DATE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
          FOREIGN KEY (assigned_to) REFERENCES users(id) ON DELETE SET NULL,
          FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE
        )
      `;
      await db.promise().query(createTableQuery);
    }
    
    // Check if user is authorized to create tasks in this project
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
    
    // Insert task
    const validStatus = ['todo', 'in_progress', 'done'].includes(status) ? status : 'todo';
    
    const query = `
      INSERT INTO project_tasks 
        (project_id, title, description, status, assigned_to, created_by, due_date)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `;
    
    const [result] = await db.promise().query(query, [
      projectId,
      title,
      description || null,
      validStatus,
      assignedTo || null,
      userId,
      dueDate || null
    ]);
    
    // Get the created task
    const getTaskQuery = `
      SELECT 
        t.id, 
        t.title, 
        t.description, 
        t.status,
        t.due_date,
        t.created_at,
        creator.id as creator_id,
        creator.name as creator_name,
        assignee.id as assignee_id,
        assignee.name as assignee_name
      FROM project_tasks t
      JOIN users creator ON t.created_by = creator.id
      LEFT JOIN users assignee ON t.assigned_to = assignee.id
      WHERE t.id = ?
    `;
    
    const [tasks] = await db.promise().query(getTaskQuery, [result.insertId]);
    
    res.status(201).json(tasks[0]);
  } catch (error) {
    console.error('Error creating task:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// Update task status
router.put('/:projectId/task/:taskId', auth, async (req, res) => {
  try {
    const { projectId, taskId } = req.params;
    const { status, assignedTo, description, title, dueDate } = req.body;
    const userId = req.user.id;
    
    // Check if user is authorized to update tasks in this project
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
    
    // Check if task exists
    const checkTaskQuery = `
      SELECT * FROM project_tasks
      WHERE id = ? AND project_id = ?
    `;
    
    const [taskCheck] = await db.promise().query(checkTaskQuery, [taskId, projectId]);
    
    if (taskCheck.length === 0) {
      return res.status(404).json({ error: 'Task not found' });
    }
    
    // Update task
    const updateFields = [];
    const updateParams = [];
    
    if (status && ['todo', 'in_progress', 'done'].includes(status)) {
      updateFields.push('status = ?');
      updateParams.push(status);
    }
    
    if (assignedTo !== undefined) {
      updateFields.push('assigned_to = ?');
      updateParams.push(assignedTo === null ? null : assignedTo);
    }
    
    if (description !== undefined) {
      updateFields.push('description = ?');
      updateParams.push(description);
    }
    
    if (title) {
      updateFields.push('title = ?');
      updateParams.push(title);
    }
    
    if (dueDate !== undefined) {
      updateFields.push('due_date = ?');
      updateParams.push(dueDate === null ? null : dueDate);
    }
    
    if (updateFields.length === 0) {
      return res.status(400).json({ error: 'No fields to update' });
    }
    
    const updateQuery = `
      UPDATE project_tasks
      SET ${updateFields.join(', ')}
      WHERE id = ? AND project_id = ?
    `;
    
    await db.promise().query(updateQuery, [...updateParams, taskId, projectId]);
    
    // Get updated task
    const getTaskQuery = `
      SELECT 
        t.id, 
        t.title, 
        t.description, 
        t.status,
        t.due_date,
        t.created_at,
        creator.id as creator_id,
        creator.name as creator_name,
        assignee.id as assignee_id,
        assignee.name as assignee_name
      FROM project_tasks t
      JOIN users creator ON t.created_by = creator.id
      LEFT JOIN users assignee ON t.assigned_to = assignee.id
      WHERE t.id = ?
    `;
    
    const [tasks] = await db.promise().query(getTaskQuery, [taskId]);
    
    res.json(tasks[0]);
  } catch (error) {
    console.error('Error updating task:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// Delete a task
router.delete('/:projectId/task/:taskId', auth, async (req, res) => {
  try {
    const { projectId, taskId } = req.params;
    const userId = req.user.id;
    
    // Check if user is part of the project
    const checkMemberQuery = `
      SELECT 1 FROM project_team 
      WHERE project_id = ? AND user_id = ?
      UNION
      SELECT 1 FROM projects
      WHERE id = ? AND created_by = ?
    `;
    
    const [memberCheck] = await db.promise().query(checkMemberQuery, [projectId, userId, projectId, userId]);
    
    if (memberCheck.length === 0) {
      return res.status(403).json({ error: 'You do not have access to this project' });
    }
    
    // Check if task exists and was created by this user or user is project owner
    const checkTaskQuery = `
      SELECT t.id, p.created_by as project_owner 
      FROM project_tasks t
      JOIN projects p ON t.project_id = p.id
      WHERE t.id = ? AND t.project_id = ?
    `;
    
    const [taskCheck] = await db.promise().query(checkTaskQuery, [taskId, projectId]);
    
    if (taskCheck.length === 0) {
      return res.status(404).json({ error: 'Task not found' });
    }
    
    // Only the project owner or task creator can delete tasks
    const isProjectOwner = taskCheck[0].project_owner === userId;
    
    if (!isProjectOwner) {
      const checkCreatorQuery = `
        SELECT * FROM project_tasks
        WHERE id = ? AND created_by = ?
      `;
      
      const [creatorCheck] = await db.promise().query(checkCreatorQuery, [taskId, userId]);
      
      if (creatorCheck.length === 0) {
        return res.status(403).json({ error: 'You are not authorized to delete this task' });
      }
    }
    
    // Delete task
    const deleteQuery = `
      DELETE FROM project_tasks
      WHERE id = ? AND project_id = ?
    `;
    
    await db.promise().query(deleteQuery, [taskId, projectId]);
    
    res.json({ message: 'Task deleted successfully' });
  } catch (error) {
    console.error('Error deleting task:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
