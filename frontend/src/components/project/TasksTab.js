import React, { useState } from 'react';
import '../../styles/tasksTab.css';

const TasksTab = ({ tasks, onCreateTask, onUpdateTask, members }) => {
  const [draggedTask, setDraggedTask] = useState(null);
  const [editingTask, setEditingTask] = useState(null);
  const [showEditModal, setShowEditModal] = useState(false);
  
  const handleEditInputChange = (e) => {
    const { name, value } = e.target;
    setEditingTask(prev => ({
      ...prev,
      [name]: value
    }));
  };
  
  const handleEditSubmit = (e) => {
    e.preventDefault();
    if (!editingTask.title.trim()) return;
    
    // Format data to match what the backend expects
    const taskData = {
      title: editingTask.title,
      description: editingTask.description,
      status: editingTask.status,
      assigned_to: editingTask.assignedTo || null, // Use assigned_to instead of assignedTo
      due_date: editingTask.dueDate || null // Use due_date instead of dueDate
    };
    
    onUpdateTask(editingTask.id, taskData);
    setShowEditModal(false);
    setEditingTask(null);
  };
  
  const openEditModal = (task) => {
    setEditingTask({
      ...task,
      assignedTo: task.assigned_to || '',
      dueDate: task.due_date || ''
    });
    setShowEditModal(true);
  };
  
  const handleStatusUpdate = (taskId, newStatus) => {
    const taskToUpdate = Object.values(tasks)
      .flat()
      .find(task => task.id === taskId);
    
    if (taskToUpdate) {
      onUpdateTask(taskId, { ...taskToUpdate, status: newStatus });
    }
  };
  
  // Drag and drop handlers
  const handleDragStart = (task) => {
    setDraggedTask(task);
  };
  
  const handleDragOver = (e) => {
    e.preventDefault();
  };
  
  const handleDrop = (status) => {
    if (!draggedTask) return;
    
    // Only update if status changed
    if (draggedTask.status !== status) {
      onUpdateTask(draggedTask.id, { ...draggedTask, status });
    }
    
    setDraggedTask(null);
  };
  
  const getStatusDisplay = (status) => {
    switch(status) {
      case 'todo': return 'To Do';
      case 'in_progress': return 'In Progress';
      case 'done': return 'Done';
      default: return status;
    }
  };
  
  const formatDate = (dateString) => {
    if (!dateString) return '';
    const options = { year: 'numeric', month: 'short', day: 'numeric' };
    return new Date(dateString).toLocaleDateString(undefined, options);
  };

  return (
    <div className="tasks-tab">
      <div className="task-board">
        {['todo', 'in_progress', 'done'].map(status => (
          <div 
            key={status} 
            className="task-column"
            onDragOver={handleDragOver}
            onDrop={() => handleDrop(status)}
          >
            <h3>{getStatusDisplay(status)} ({tasks[status]?.length || 0})</h3>
            <div className="task-list">
              {tasks[status]?.map(task => (
                <div 
                  key={task.id} 
                  className="task-card"
                  draggable
                  onDragStart={() => handleDragStart(task)}
                >
                  <h4>{task.title}</h4>
                  {task.description && <p className="task-description">{task.description}</p>}
                  
                  <div className="task-meta">
                    {task.assignee_name && (
                      <div className="task-assignee">
                        <span className="meta-label">Assigned to:</span>
                        <span className="meta-value">{task.assignee_name}</span>
                      </div>
                    )}
                    
                    {task.due_date && (
                      <div className="task-due-date">
                        <span className="meta-label">Due:</span>
                        <span className="meta-value">{formatDate(task.due_date)}</span>
                      </div>
                    )}
                    
                    <div className="task-creator">
                      <span className="meta-label">Created by:</span>
                      <span className="meta-value">{task.creator_name}</span>
                    </div>
                  </div>
                  
                  {/* Task actions */}
                  <div className="task-actions">
                    <button 
                      className="edit-task-btn"
                      onClick={() => openEditModal(task)}
                    >
                      Edit
                    </button>
                    
                    <div className="status-actions">
                      {status !== 'todo' && (
                        <button 
                          className="status-btn todo-btn"
                          onClick={() => handleStatusUpdate(task.id, 'todo')}
                        >
                          To Do
                        </button>
                      )}
                      {status !== 'in_progress' && (
                        <button 
                          className="status-btn progress-btn"
                          onClick={() => handleStatusUpdate(task.id, 'in_progress')}
                        >
                          In Progress
                        </button>
                      )}
                      {status !== 'done' && (
                        <button 
                          className="status-btn done-btn"
                          onClick={() => handleStatusUpdate(task.id, 'done')}
                        >
                          Done
                        </button>
                      )}
                    </div>
                  </div>
                </div>
              ))}
              
              {tasks[status]?.length === 0 && (
                <p className="empty-column-message">No tasks</p>
              )}
            </div>
          </div>
        ))}
      </div>
      
      {/* Edit Task Modal */}
      {showEditModal && editingTask && (
        <div className="modal-overlay">
          <div className="edit-task-modal">
            <h3>Edit Task</h3>
            <form onSubmit={handleEditSubmit} className="task-form">
              <div className="form-group">
                <label htmlFor="edit-title">Title*</label>
                <input
                  type="text"
                  id="edit-title"
                  name="title"
                  value={editingTask.title}
                  onChange={handleEditInputChange}
                  required
                />
              </div>
              
              <div className="form-group">
                <label htmlFor="edit-description">Description</label>
                <textarea
                  id="edit-description"
                  name="description"
                  value={editingTask.description}
                  onChange={handleEditInputChange}
                  rows="3"
                ></textarea>
              </div>
              
              <div className="form-row">
                <div className="form-group">
                  <label htmlFor="edit-status">Status</label>
                  <select
                    id="edit-status"
                    name="status"
                    value={editingTask.status}
                    onChange={handleEditInputChange}
                  >
                    <option value="todo">To Do</option>
                    <option value="in_progress">In Progress</option>
                    <option value="done">Done</option>
                  </select>
                </div>
                
                <div className="form-group">
                  <label htmlFor="edit-assignedTo">Assign To</label>
                  <select
                    id="edit-assignedTo"
                    name="assignedTo"
                    value={editingTask.assignedTo}
                    onChange={handleEditInputChange}
                  >
                    <option value="">Unassigned</option>
                    {members.map(member => (
                      <option key={member.id} value={member.id}>
                        {member.name}
                      </option>
                    ))}
                  </select>
                </div>
                
                <div className="form-group">
                  <label htmlFor="edit-dueDate">Due Date</label>
                  <input
                    type="date"
                    id="edit-dueDate"
                    name="dueDate"
                    value={editingTask.dueDate}
                    onChange={handleEditInputChange}
                  />
                </div>
              </div>
              
              <div className="modal-actions">
                <button type="submit" className="save-btn">Save Changes</button>
                <button 
                  type="button" 
                  className="cancel-btn"
                  onClick={() => {
                    setShowEditModal(false);
                    setEditingTask(null);
                  }}
                >
                  Cancel
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

export default TasksTab;
