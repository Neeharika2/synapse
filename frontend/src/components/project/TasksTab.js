import React, { useState } from 'react';
import '../../styles/tasksTab.css';

const TasksTab = ({ tasks, onCreateTask, onUpdateTask, members }) => {
  const [newTask, setNewTask] = useState({
    title: '',
    description: '',
    status: 'todo',
    assignedTo: '',
    dueDate: ''
  });
  
  const [draggedTask, setDraggedTask] = useState(null);
  
  const handleInputChange = (e) => {
    const { name, value } = e.target;
    setNewTask(prev => ({
      ...prev,
      [name]: value
    }));
  };
  
  const handleSubmit = (e) => {
    e.preventDefault();
    if (!newTask.title.trim()) return;
    
    onCreateTask(newTask);
    
    // Reset form
    setNewTask({
      title: '',
      description: '',
      status: 'todo',
      assignedTo: '',
      dueDate: ''
    });
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
      <div className="task-form-container">
        <h3>Add New Task</h3>
        <form onSubmit={handleSubmit} className="task-form">
          <div className="form-group">
            <label htmlFor="title">Title*</label>
            <input
              type="text"
              id="title"
              name="title"
              value={newTask.title}
              onChange={handleInputChange}
              placeholder="Task title"
              required
            />
          </div>
          
          <div className="form-group">
            <label htmlFor="description">Description</label>
            <textarea
              id="description"
              name="description"
              value={newTask.description}
              onChange={handleInputChange}
              placeholder="Task description"
              rows="3"
            ></textarea>
          </div>
          
          <div className="form-row">
            <div className="form-group">
              <label htmlFor="status">Status</label>
              <select
                id="status"
                name="status"
                value={newTask.status}
                onChange={handleInputChange}
              >
                <option value="todo">To Do</option>
                <option value="in_progress">In Progress</option>
                <option value="done">Done</option>
              </select>
            </div>
            
            <div className="form-group">
              <label htmlFor="assignedTo">Assign To</label>
              <select
                id="assignedTo"
                name="assignedTo"
                value={newTask.assignedTo}
                onChange={handleInputChange}
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
              <label htmlFor="dueDate">Due Date</label>
              <input
                type="date"
                id="dueDate"
                name="dueDate"
                value={newTask.dueDate}
                onChange={handleInputChange}
              />
            </div>
          </div>
          
          <button type="submit" className="add-task-btn">Add Task</button>
        </form>
      </div>
      
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
                </div>
              ))}
              
              {tasks[status]?.length === 0 && (
                <p className="empty-column-message">No tasks</p>
              )}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};

export default TasksTab;
