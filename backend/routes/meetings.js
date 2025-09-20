const express = require('express');
const router = express.Router();
const db = require('../config/database');
const auth = require('../middleware/auth');

// Get all meetings for a project
router.get('/:projectId', auth, async (req, res) => {
  try {
    const { projectId } = req.params;
    const userId = req.user.id;
    
    // Check if project_meetings table exists
    const checkTableQuery = `
      SELECT COUNT(*) as count FROM information_schema.tables 
      WHERE table_schema = DATABASE() AND table_name = 'project_meetings'
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
    
    // Get all meetings
    const query = `
      SELECT 
        pm.id, 
        pm.title, 
        pm.description, 
        pm.meeting_date, 
        pm.meeting_time, 
        pm.meeting_link,
        pm.created_at,
        u.id as organizer_id,
        u.name as organizer_name
      FROM project_meetings pm
      JOIN users u ON pm.organized_by = u.id
      WHERE pm.project_id = ?
      ORDER BY pm.meeting_date ASC, pm.meeting_time ASC
    `;
    
    const [rows] = await db.promise().query(query, [projectId]);
    res.json(rows);
  } catch (error) {
    console.error('Error fetching project meetings:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// Schedule a new meeting
router.post('/:projectId', auth, async (req, res) => {
  try {
    const { projectId } = req.params;
    const { title, description, date, time, link } = req.body;
    const userId = req.user.id;
    
    if (!title || !date || !time) {
      return res.status(400).json({ error: 'Title, date and time are required' });
    }
    
    // Check if project_meetings table exists
    const checkTableQuery = `
      SELECT COUNT(*) as count FROM information_schema.tables 
      WHERE table_schema = DATABASE() AND table_name = 'project_meetings'
    `;
    
    const [tableCheck] = await db.promise().query(checkTableQuery);
    if (tableCheck[0].count === 0) {
      // Create the table
      const createTableQuery = `
        CREATE TABLE project_meetings (
          id INT AUTO_INCREMENT PRIMARY KEY,
          project_id INT NOT NULL,
          title VARCHAR(255) NOT NULL,
          description TEXT,
          meeting_date DATE NOT NULL,
          meeting_time TIME NOT NULL,
          meeting_link VARCHAR(255),
          organized_by INT NOT NULL,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
          FOREIGN KEY (organized_by) REFERENCES users(id) ON DELETE CASCADE
        )
      `;
      await db.promise().query(createTableQuery);
    }
    
    // Check if user is authorized to schedule meetings in this project
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
    
    // Insert meeting
    const query = `
      INSERT INTO project_meetings 
        (project_id, title, description, meeting_date, meeting_time, meeting_link, organized_by)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `;
    
    const [result] = await db.promise().query(query, [
      projectId,
      title,
      description || null,
      date,
      time,
      link || null,
      userId
    ]);
    
    // Get the scheduled meeting
    const getMeetingQuery = `
      SELECT 
        pm.id, 
        pm.title, 
        pm.description, 
        pm.meeting_date, 
        pm.meeting_time, 
        pm.meeting_link,
        pm.created_at,
        u.id as organizer_id,
        u.name as organizer_name
      FROM project_meetings pm
      JOIN users u ON pm.organized_by = u.id
      WHERE pm.id = ?
    `;
    
    const [meetings] = await db.promise().query(getMeetingQuery, [result.insertId]);
    
    res.status(201).json(meetings[0]);
  } catch (error) {
    console.error('Error scheduling meeting:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// Update a meeting
router.put('/:projectId/meeting/:meetingId', auth, async (req, res) => {
  try {
    const { projectId, meetingId } = req.params;
    const { title, description, date, time, link } = req.body;
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
    
    // Check if meeting exists and was organized by this user or user is project owner
    const checkMeetingQuery = `
      SELECT m.id, p.created_by as project_owner, m.organized_by
      FROM project_meetings m
      JOIN projects p ON m.project_id = p.id
      WHERE m.id = ? AND m.project_id = ?
    `;
    
    const [meetingCheck] = await db.promise().query(checkMeetingQuery, [meetingId, projectId]);
    
    if (meetingCheck.length === 0) {
      return res.status(404).json({ error: 'Meeting not found' });
    }
    
    // Only the project owner or meeting organizer can update meetings
    const isProjectOwner = meetingCheck[0].project_owner === userId;
    const isOrganizer = meetingCheck[0].organized_by === userId;
    
    if (!isProjectOwner && !isOrganizer) {
      return res.status(403).json({ error: 'You are not authorized to update this meeting' });
    }
    
    // Update meeting
    const updateFields = [];
    const updateParams = [];
    
    if (title) {
      updateFields.push('title = ?');
      updateParams.push(title);
    }
    
    if (description !== undefined) {
      updateFields.push('description = ?');
      updateParams.push(description);
    }
    
    if (date) {
      updateFields.push('meeting_date = ?');
      updateParams.push(date);
    }
    
    if (time) {
      updateFields.push('meeting_time = ?');
      updateParams.push(time);
    }
    
    if (link !== undefined) {
      updateFields.push('meeting_link = ?');
      updateParams.push(link);
    }
    
    if (updateFields.length === 0) {
      return res.status(400).json({ error: 'No fields to update' });
    }
    
    const updateQuery = `
      UPDATE project_meetings
      SET ${updateFields.join(', ')}
      WHERE id = ? AND project_id = ?
    `;
    
    await db.promise().query(updateQuery, [...updateParams, meetingId, projectId]);
    
    // Get updated meeting
    const getMeetingQuery = `
      SELECT 
        pm.id, 
        pm.title, 
        pm.description, 
        pm.meeting_date, 
        pm.meeting_time, 
        pm.meeting_link,
        pm.created_at,
        u.id as organizer_id,
        u.name as organizer_name
      FROM project_meetings pm
      JOIN users u ON pm.organized_by = u.id
      WHERE pm.id = ?
    `;
    
    const [meetings] = await db.promise().query(getMeetingQuery, [meetingId]);
    
    res.json(meetings[0]);
  } catch (error) {
    console.error('Error updating meeting:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// Delete a meeting
router.delete('/:projectId/meeting/:meetingId', auth, async (req, res) => {
  try {
    const { projectId, meetingId } = req.params;
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
    
    // Check if meeting exists and was organized by this user or user is project owner
    const checkMeetingQuery = `
      SELECT m.id, p.created_by as project_owner, m.organized_by
      FROM project_meetings m
      JOIN projects p ON m.project_id = p.id
      WHERE m.id = ? AND m.project_id = ?
    `;
    
    const [meetingCheck] = await db.promise().query(checkMeetingQuery, [meetingId, projectId]);
    
    if (meetingCheck.length === 0) {
      return res.status(404).json({ error: 'Meeting not found' });
    }
    
    // Only the project owner or meeting organizer can delete meetings
    const isProjectOwner = meetingCheck[0].project_owner === userId;
    const isOrganizer = meetingCheck[0].organized_by === userId;
    
    if (!isProjectOwner && !isOrganizer) {
      return res.status(403).json({ error: 'You are not authorized to delete this meeting' });
    }
    
    // Delete meeting
    const deleteQuery = `
      DELETE FROM project_meetings
      WHERE id = ? AND project_id = ?
    `;
    
    await db.promise().query(deleteQuery, [meetingId, projectId]);
    
    res.json({ message: 'Meeting deleted successfully' });
  } catch (error) {
    console.error('Error deleting meeting:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
