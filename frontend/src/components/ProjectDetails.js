import React, { useState, useEffect, useRef } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import axios from 'axios';
import { io } from 'socket.io-client';
import Layout from './Layout';
import '../styles/projectDetails.css';
import '../styles/modals.css';
import TasksTab from './project/TasksTab'; // Add this import at the top with other imports

const ProjectDetails = ({ setToken }) => {
  const { projectId } = useParams();
  const navigate = useNavigate();
  const socketRef = useRef();
  const [project, setProject] = useState(null);
  const [members, setMembers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [activeTab, setActiveTab] = useState('chat');
  const [notification, setNotification] = useState({ show: false, message: '', type: '' });

  // Data state
  const [messages, setMessages] = useState([]);
  const [files, setFiles] = useState([]);
  const [tasks, setTasks] = useState({
    todo: [],
    in_progress: [],
    done: []
  });
  const [meetings, setMeetings] = useState([]);

  // Member panel toggle
  const [showMembersPanel, setShowMembersPanel] = useState(false);

  // Modal states
  const [showTaskModal, setShowTaskModal] = useState(false);
  const [showMeetingModal, setShowMeetingModal] = useState(false);
  const [newTask, setNewTask] = useState({
    title: '',
    description: '',
    status: 'todo',
    assignedTo: '',
    dueDate: ''
  });
  const [newMeeting, setNewMeeting] = useState({
    title: '',
    description: '',
    date: '',
    time: '',
    link: ''
  });

  // Socket.io connection
  useEffect(() => {
    // Connect to Socket.io server
    socketRef.current = io('http://localhost:5000');
    
    // Join project room
    socketRef.current.emit('joinProject', projectId);
    
    // Listen for new messages
    socketRef.current.on('newMessage', (message) => {
      setMessages(prevMessages => [...prevMessages, message]);
    });
    
    // Cleanup on unmount
    return () => {
      socketRef.current.emit('leaveProject', projectId);
      socketRef.current.disconnect();
    };
  }, [projectId]);

  // Show notification helper
  const showNotification = (message, type = 'success') => {
    setNotification({ show: true, message, type });
    setTimeout(() => {
      setNotification({ show: false, message: '', type: '' });
    }, 3000);
  };

  // Fetch project details
  useEffect(() => {
    const fetchProjectDetails = async () => {
      setLoading(true);
      try {
        const token = localStorage.getItem('token');
        
        // Fetch project details
        const response = await axios.get(`http://localhost:5000/api/projects/${projectId}`, {
          headers: { Authorization: `Bearer ${token}` }
        });
        
        setProject(response.data);
        setMembers(response.data.members || []);
        
        // Fetch initial data for all tabs
        await Promise.all([
          fetchChatMessages(),
          fetchFiles(),
          fetchTasks(),
          fetchMeetings()
        ]);
        
        setError('');
      } catch (error) {
        console.error('Error fetching project details:', error);
        setError('Failed to load project details. Please try again.');
      } finally {
        setLoading(false);
      }
    };
    
    fetchProjectDetails();
  }, [projectId]);

  // Fetch chat messages
  const fetchChatMessages = async () => {
    try {
      const token = localStorage.getItem('token');
      const response = await axios.get(`http://localhost:5000/api/chat/${projectId}`, {
        headers: { Authorization: `Bearer ${token}` }
      });
      setMessages(response.data);
    } catch (error) {
      console.error('Error fetching chat messages:', error);
      // Continue even if this fails
    }
  };

  // Fetch files
  const fetchFiles = async () => {
    try {
      const token = localStorage.getItem('token');
      const response = await axios.get(`http://localhost:5000/api/files/${projectId}`, {
        headers: { Authorization: `Bearer ${token}` }
      });
      setFiles(response.data);
    } catch (error) {
      console.error('Error fetching files:', error);
      // Continue even if this fails
    }
  };

  // Fetch tasks
  const fetchTasks = async () => {
    try {
      const token = localStorage.getItem('token');
      const response = await axios.get(`http://localhost:5000/api/tasks/${projectId}`, {
        headers: { Authorization: `Bearer ${token}` }
      });
      
      // Group tasks by status
      const groupedTasks = {
        todo: [],
        in_progress: [],
        done: []
      };
      
      response.data.forEach(task => {
        if (task.status === 'todo') {
          groupedTasks.todo.push(task);
        } else if (task.status === 'in_progress') {
          groupedTasks.in_progress.push(task);
        } else if (task.status === 'done') {
          groupedTasks.done.push(task);
        }
      });
      
      setTasks(groupedTasks);
    } catch (error) {
      console.error('Error fetching tasks:', error);
      // Continue even if this fails
    }
  };

  // Fetch meetings
  const fetchMeetings = async () => {
    try {
      const token = localStorage.getItem('token');
      const response = await axios.get(`http://localhost:5000/api/meetings/${projectId}`, {
        headers: { Authorization: `Bearer ${token}` }
      });
      setMeetings(response.data);
    } catch (error) {
      console.error('Error fetching meetings:', error);
      // Continue even if this fails
    }
  };

  // Send chat message
  const handleSendMessage = async (message) => {
    if (!message.trim()) return;
    
    try {
      const token = localStorage.getItem('token');
      const userId = JSON.parse(atob(token.split('.')[1])).id;
      
      // Emit message through Socket.io
      socketRef.current.emit('sendMessage', {
        projectId,
        userId,
        message
      });
      
      // Also send via REST API as fallback
      await axios.post(
        `http://localhost:5000/api/chat/${projectId}`,
        { message },
        { headers: { Authorization: `Bearer ${token}` } }
      );
    } catch (error) {
      console.error('Error sending message:', error);
      showNotification('Failed to send message', 'error');
    }
  };

  // Upload file
  const handleFileUpload = async (file) => {
    try {
      const token = localStorage.getItem('token');
      
      const formData = new FormData();
      formData.append('file', file);
      
      const response = await axios.post(
        `http://localhost:5000/api/files/${projectId}/upload`,
        formData,
        {
          headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'multipart/form-data'
          }
        }
      );
      
      setFiles(prevFiles => [...prevFiles, response.data]);
      showNotification('File uploaded successfully');
    } catch (error) {
      console.error('Error uploading file:', error);
      showNotification('Failed to upload file', 'error');
    }
  };

  // Create task
  const handleCreateTask = async (taskData) => {
    try {
      const token = localStorage.getItem('token');
      
      const response = await axios.post(
        `http://localhost:5000/api/tasks/${projectId}`,
        taskData,
        {
          headers: { Authorization: `Bearer ${token}` }
        }
      );
      
      // Add task to state
      const newTask = response.data;
      setTasks(prevTasks => ({
        ...prevTasks,
        [newTask.status]: [...prevTasks[newTask.status], newTask]
      }));
      
      showNotification('Task created successfully');
    } catch (error) {
      console.error('Error creating task:', error);
      showNotification('Failed to create task', 'error');
    }
  };

  // Update task
  const handleUpdateTask = async (taskId, taskData) => {
    try {
      const token = localStorage.getItem('token');
      
      const response = await axios.put(
        `http://localhost:5000/api/tasks/${projectId}/task/${taskId}`,
        taskData,
        {
          headers: { Authorization: `Bearer ${token}` }
        }
      );
      
      // Handle task status change (moving between columns)
      const updatedTask = response.data;
      const oldStatus = Object.keys(tasks).find(status => 
        tasks[status].some(task => task.id === taskId)
      );
      
      if (oldStatus && oldStatus !== updatedTask.status) {
        // Task moved to a different column
        setTasks(prevTasks => ({
          ...prevTasks,
          [oldStatus]: prevTasks[oldStatus].filter(task => task.id !== taskId),
          [updatedTask.status]: [...prevTasks[updatedTask.status], updatedTask]
        }));
      } else {
        // Task updated but status didn't change
        setTasks(prevTasks => ({
          ...prevTasks,
          [updatedTask.status]: prevTasks[updatedTask.status].map(task => 
            task.id === taskId ? updatedTask : task
          )
        }));
      }
      
      showNotification('Task updated successfully');
    } catch (error) {
      console.error('Error updating task:', error);
      showNotification('Failed to update task', 'error');
    }
  };

  // Create meeting
  const handleCreateMeeting = async (meetingData) => {
    try {
      const token = localStorage.getItem('token');
      
      const response = await axios.post(
        `http://localhost:5000/api/meetings/${projectId}`,
        meetingData,
        {
          headers: { Authorization: `Bearer ${token}` }
        }
      );
      
      setMeetings(prevMeetings => [...prevMeetings, response.data]);
      showNotification('Meeting scheduled successfully');
    } catch (error) {
      console.error('Error scheduling meeting:', error);
      showNotification('Failed to schedule meeting', 'error');
    }
  };

  // Toggle team members panel
  const toggleMembersPanel = () => {
    setShowMembersPanel(!showMembersPanel);
  };

  // Task modal handlers
  const openTaskModal = () => {
    setNewTask({
      title: '',
      description: '',
      status: 'todo',
      assignedTo: '',
      dueDate: ''
    });
    setShowTaskModal(true);
  };

  const closeTaskModal = () => {
    setShowTaskModal(false);
  };

  const handleTaskInputChange = (e) => {
    const { name, value } = e.target;
    setNewTask(prev => ({ ...prev, [name]: value }));
  };

  const handleTaskSubmit = async (e) => {
    e.preventDefault();
    
    try {
      await handleCreateTask(newTask);
      setShowTaskModal(false);
    } catch (error) {
      console.error('Error submitting task:', error);
    }
  };

  // Meeting modal handlers
  const openMeetingModal = () => {
    setNewMeeting({
      title: '',
      description: '',
      date: '',
      time: '',
      link: ''
    });
    setShowMeetingModal(true);
  };

  const closeMeetingModal = () => {
    setShowMeetingModal(false);
  };

  const handleMeetingInputChange = (e) => {
    const { name, value } = e.target;
    setNewMeeting(prev => ({ ...prev, [name]: value }));
  };

  const handleMeetingSubmit = async (e) => {
    e.preventDefault();
    
    try {
      await handleCreateMeeting(newMeeting);
      setShowMeetingModal(false);
    } catch (error) {
      console.error('Error submitting meeting:', error);
    }
  };

  if (loading) {
    return (
      <Layout setToken={setToken}>
        <div className="loading-state">Loading project details...</div>
      </Layout>
    );
  }

  if (error) {
    return (
      <Layout setToken={setToken}>
        <div className="error-state">
          <p>{error}</p>
          <button onClick={() => navigate('/teams')} className="back-button">
            Back to My Projects
          </button>
        </div>
      </Layout>
    );
  }

  if (!project) {
    return (
      <Layout setToken={setToken}>
        <div className="error-state">
          <p>Project not found</p>
          <button onClick={() => navigate('/teams')} className="back-button">
            Back to My Projects
          </button>
        </div>
      </Layout>
    );
  }

  return (
    <Layout setToken={setToken}>
      <div className="project-details-container">
        {notification.show && (
          <div className={`notification ${notification.type}`}>
            {notification.message}
          </div>
        )}
        
        <div className="project-header">
          <div className="project-title-section">
            <h1>{project.title}</h1>
            <p className="project-description">{project.description}</p>
            <button onClick={() => navigate('/teams')} className="back-link">
              &larr; Back to My Projects
            </button>
          </div>
          
          <div className="team-members-btn-container">
            <button 
              className="team-members-btn"
              onClick={toggleMembersPanel}
            >
              <span className="member-count">{members.length}</span>
              <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path>
                <circle cx="9" cy="7" r="4"></circle>
                <path d="M23 21v-2a4 4 0 0 0-3-3.87"></path>
                <path d="M16 3.13a4 4 0 0 1 0 7.75"></path>
              </svg>
              <span>Team Members</span>
            </button>
          </div>
        </div>
        
        {/* Team Members Panel */}
        <div className={`members-panel ${showMembersPanel ? 'show' : ''}`}>
          <div className="panel-header">
            <h3>Team Members ({members.length})</h3>
            <button className="close-panel-btn" onClick={toggleMembersPanel}>×</button>
          </div>
          <ul className="member-list">
            {members.map(member => (
              <li key={member.id} className="member-item">
                <div className="member-avatar">{member.name?.charAt(0) || 'U'}</div>
                <div className="member-info">
                  <span className="member-name">{member.name}</span>
                  <span className="member-role">{member.role}</span>
                  <span className="member-email">{member.email}</span>
                </div>
              </li>
            ))}
            {members.length === 0 && <li className="no-members">No team members yet</li>}
          </ul>
        </div>

        <div className="project-tabs-container">
          <div className="project-tabs">
            <button 
              className={`tab-button ${activeTab === 'chat' ? 'active' : ''}`}
              onClick={() => setActiveTab('chat')}
            >
              Chat
            </button>
            <button 
              className={`tab-button ${activeTab === 'files' ? 'active' : ''}`}
              onClick={() => setActiveTab('files')}
            >
              Files
            </button>
            <button 
              className={`tab-button ${activeTab === 'tasks' ? 'active' : ''}`}
              onClick={() => setActiveTab('tasks')}
            >
              Tasks
            </button>
            <button 
              className={`tab-button ${activeTab === 'meetings' ? 'active' : ''}`}
              onClick={() => setActiveTab('meetings')}
            >
              Meetings
            </button>
          </div>

          <div className="tab-content">
            {activeTab === 'chat' && (
              <div className="chat-tab">
                <div className="chat-messages">
                  {messages.length === 0 && (
                    <div className="no-messages">
                      <p>No messages yet. Start the conversation!</p>
                    </div>
                  )}
                  
                  {messages.map(message => (
                    <div key={message.id} className="chat-message">
                      <div className="message-sender">{message.user_name}</div>
                      <div className="message-text">{message.message}</div>
                      <div className="message-time">
                        {new Date(message.created_at).toLocaleTimeString()}
                      </div>
                    </div>
                  ))}
                </div>
                
                <div className="chat-input">
                  <textarea 
                    placeholder="Type a message..."
                    onKeyPress={(e) => {
                      if (e.key === 'Enter' && !e.shiftKey) {
                        e.preventDefault();
                        handleSendMessage(e.target.value);
                        e.target.value = '';
                      }
                    }}
                  />
                  <button onClick={(e) => {
                    const textarea = e.target.previousSibling;
                    handleSendMessage(textarea.value);
                    textarea.value = '';
                  }}>Send</button>
                </div>
              </div>
            )}

            {activeTab === 'files' && (
              <div className="files-tab">
                <div className="file-upload-section">
                  <input 
                    type="file"
                    id="file-upload"
                    onChange={(e) => {
                      if (e.target.files && e.target.files[0]) {
                        handleFileUpload(e.target.files[0]);
                      }
                    }}
                    style={{ display: 'none' }}
                  />
                  <label htmlFor="file-upload" className="file-upload-btn">
                    Choose File to Upload
                  </label>
                </div>
                
                <div className="files-list">
                  <h3>Project Files</h3>
                  
                  {files.length === 0 ? (
                    <p className="no-files">No files have been uploaded yet.</p>
                  ) : (
                    <table className="files-table">
                      <thead>
                        <tr>
                          <th>Name</th>
                          <th>Size</th>
                          <th>Uploaded By</th>
                          <th>Date</th>
                          <th>Actions</th>
                        </tr>
                      </thead>
                      <tbody>
                        {files.map(file => (
                          <tr key={file.id}>
                            <td>{file.file_name}</td>
                            <td>{Math.round(file.file_size/1024)} KB</td>
                            <td>{file.uploaded_by_name}</td>
                            <td>{new Date(file.uploaded_at).toLocaleDateString()}</td>
                            <td>
                              <button 
                                className="download-btn"
                                onClick={() => {
                                  window.open(
                                    `http://localhost:5000/api/files/${projectId}/download/${file.id}`,
                                    '_blank'
                                  );
                                }}
                              >
                                Download
                              </button>
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  )}
                </div>
              </div>
            )}

            {activeTab === 'tasks' && (
              <div className="tasks-tab">
                <div className="tasks-header">
                  <h2>Task Board</h2>
                  <button className="create-btn" onClick={openTaskModal}>
                    <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                      <line x1="12" y1="5" x2="12" y2="19"></line>
                      <line x1="5" y1="12" x2="19" y2="12"></line>
                    </svg>
                    Create Task
                  </button>
                </div>
                
                {/* Replace the task board with TasksTab component */}
                <TasksTab 
                  tasks={tasks}
                  onCreateTask={handleCreateTask}
                  onUpdateTask={handleUpdateTask}
                  members={members}
                />

                {/* Task Creation Modal */}
                {showTaskModal && (
                  <div className="modal-overlay">
                    <div className="modal">
                      <div className="modal-header">
                        <h3>Create New Task</h3>
                        <button className="modal-close-btn" onClick={closeTaskModal}>×</button>
                      </div>
                      <form className="modal-form" onSubmit={handleTaskSubmit}>
                        <div className="form-group">
                          <label htmlFor="title">Title</label>
                          <input 
                            type="text" 
                            id="title" 
                            name="title" 
                            value={newTask.title}
                            onChange={handleTaskInputChange}
                            required 
                          />
                        </div>
                        
                        <div className="form-group">
                          <label htmlFor="description">Description</label>
                          <textarea 
                            id="description" 
                            name="description" 
                            rows="3"
                            value={newTask.description}
                            onChange={handleTaskInputChange}
                          ></textarea>
                        </div>
                        
                        <div className="form-row">
                          <div className="form-group">
                            <label htmlFor="status">Status</label>
                            <select 
                              id="status" 
                              name="status"
                              value={newTask.status}
                              onChange={handleTaskInputChange}
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
                              onChange={handleTaskInputChange}
                            >
                              <option value="">Unassigned</option>
                              {members.map(member => (
                                <option key={member.id} value={member.id}>
                                  {member.name}
                                </option>
                              ))}
                            </select>
                          </div>
                        </div>

                        <div className="form-group">
                          <label htmlFor="dueDate">Due Date (Optional)</label>
                          <input 
                            type="date" 
                            id="dueDate" 
                            name="dueDate"
                            value={newTask.dueDate}
                            onChange={handleTaskInputChange}
                          />
                        </div>
                        
                        <div className="modal-actions">
                          <button type="button" className="cancel-btn" onClick={closeTaskModal}>Cancel</button>
                          <button type="submit" className="submit-btn">Create Task</button>
                        </div>
                      </form>
                    </div>
                  </div>
                )}
              </div>
            )}

            {activeTab === 'meetings' && (
              <div className="meetings-tab">
                <div className="meetings-header">
                  <h2>Scheduled Meetings</h2>
                  <button className="create-btn" onClick={openMeetingModal}>
                    <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                      <line x1="12" y1="5" x2="12" y2="19"></line>
                      <line x1="5" y1="12" x2="19" y2="12"></line>
                    </svg>
                    Schedule Meeting
                  </button>
                </div>
                
                <div className="meetings-list">
                  {meetings.length === 0 ? (
                    <p className="no-meetings">No meetings have been scheduled yet.</p>
                  ) : (
                    <div className="meeting-cards">
                      {meetings.map(meeting => {
                        const meetingDate = new Date(`${meeting.meeting_date}T${meeting.meeting_time}`);
                        const isUpcoming = meetingDate > new Date();
                        
                        return (
                          <div key={meeting.id} className={`meeting-card ${isUpcoming ? 'upcoming' : 'past'}`}>
                            <h4>{meeting.title}</h4>
                            <div className="meeting-meta">
                              <div className="meeting-time">
                                <span className="meta-label">When:</span>
                                <span>{new Date(`${meeting.meeting_date}T${meeting.meeting_time}`).toLocaleString()}</span>
                              </div>
                              <div className="meeting-organizer">
                                <span className="meta-label">Organized by:</span>
                                <span>{meeting.organizer_name}</span>
                              </div>
                            </div>
                            {meeting.description && (
                              <p className="meeting-description">{meeting.description}</p>
                            )}
                            {meeting.meeting_link && isUpcoming && (
                              <a
                                href={meeting.meeting_link}
                                target="_blank"
                                rel="noopener noreferrer"
                                className="join-meeting-btn"
                              >
                                Join Meeting
                              </a>
                            )}
                          </div>
                        );
                      })}
                    </div>
                  )}
                </div>

                {/* Meeting Creation Modal */}
                {showMeetingModal && (
                  <div className="modal-overlay">
                    <div className="modal">
                      <div className="modal-header">
                        <h3>Schedule New Meeting</h3>
                        <button className="modal-close-btn" onClick={closeMeetingModal}>×</button>
                      </div>
                      <form className="modal-form" onSubmit={handleMeetingSubmit}>
                        <div className="form-group">
                          <label htmlFor="meeting-title">Meeting Title</label>
                          <input 
                            type="text" 
                            id="meeting-title" 
                            name="title"
                            value={newMeeting.title}
                            onChange={handleMeetingInputChange}
                            required 
                          />
                        </div>
                        
                        <div className="form-group">
                          <label htmlFor="meeting-description">Description/Agenda</label>
                          <textarea 
                            id="meeting-description" 
                            name="description"
                            rows="3"
                            value={newMeeting.description}
                            onChange={handleMeetingInputChange}
                          ></textarea>
                        </div>
                        
                        <div className="form-row">
                          <div className="form-group">
                            <label htmlFor="meeting-date">Date</label>
                            <input 
                              type="date" 
                              id="meeting-date" 
                              name="date"
                              value={newMeeting.date}
                              onChange={handleMeetingInputChange}
                              required 
                            />
                          </div>
                          
                          <div className="form-group">
                            <label htmlFor="meeting-time">Time</label>
                            <input 
                              type="time" 
                              id="meeting-time" 
                              name="time"
                              value={newMeeting.time}
                              onChange={handleMeetingInputChange}
                              required 
                            />
                          </div>
                        </div>
                        
                        <div className="form-group">
                          <label htmlFor="meeting-link">Meeting Link (Optional)</label>
                          <input 
                            type="url" 
                            id="meeting-link" 
                            name="link"
                            placeholder="https://meet.google.com/..."
                            value={newMeeting.link}
                            onChange={handleMeetingInputChange}
                          />
                        </div>
                        
                        <div className="modal-actions">
                          <button type="button" className="cancel-btn" onClick={closeMeetingModal}>Cancel</button>
                          <button type="submit" className="submit-btn">Schedule Meeting</button>
                        </div>
                      </form>
                    </div>
                  </div>
                )}
              </div>
            )}
          </div>
        </div>
      </div>
    </Layout>
  );
};

export default ProjectDetails;
                    