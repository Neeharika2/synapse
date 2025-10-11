import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { Link } from 'react-router-dom';
import '../styles/components.css';
import '../styles/modals.css';
import Layout from './Layout';

// Define sector options for the dropdown
const sectorOptions = [
  "Web Development",
  "Mobile App Development",
  "AI/Machine Learning",
  "Data Science",
  "Blockchain",
  "IoT",
  "Cybersecurity",
  "Game Development",
  "Cloud Computing",
  "Other"
];

// Define sort options
const sortOptions = [
  "Newest First",
  "Oldest First",
  "Alphabetical (A-Z)",
  "Alphabetical (Z-A)"
];

// Define status options
const statusOptions = [
  "All",
  "Open",
  "In Progress",
  "Completed"
];

const Dashboard = ({ setToken }) => {
  const [projects, setProjects] = useState([]);
  const [newProject, setNewProject] = useState({ 
    title: '', 
    description: '', 
    requiredSkills: '', 
    teamSize: '', 
    sector: '' 
  });
  const [showForm, setShowForm] = useState(false);
  const [activeTab, setActiveTab] = useState('all'); // 'all' or 'my'
  const [searchQuery, setSearchQuery] = useState('');
  const [isSearching, setIsSearching] = useState(false);
  const [selectedProject, setSelectedProject] = useState(null);
  const [showDetailsModal, setShowDetailsModal] = useState(false);
  const user = JSON.parse(localStorage.getItem('user'));
  
  // Filter state
  const [filters, setFilters] = useState({
    category: '',
    sortBy: 'Newest First',
    status: 'All',
    creator: 'All',
    dateCreated: ''
  });

  useEffect(() => {
    fetchProjects();
  }, []);

  const fetchProjects = async () => {
    try {
      const token = localStorage.getItem('token');
      const response = await axios.get('http://localhost:5000/api/projects', {
        headers: { Authorization: `Bearer ${token}` }
      });
      setProjects(response.data);
      setIsSearching(false);
    } catch (error) {
      console.error('Error fetching projects:', error);
      setIsSearching(false);
    }
  };
  
  const searchProjects = async () => {
    if (!searchQuery.trim()) {
      fetchProjects();
      return;
    }
    
    try {
      setIsSearching(true);
      const token = localStorage.getItem('token');
      const response = await axios.get(`http://localhost:5000/api/projects/search`, {
        headers: { Authorization: `Bearer ${token}` },
        params: { query: searchQuery }
      });
      setProjects(response.data);
      setIsSearching(false);
    } catch (error) {
      console.error('Error searching projects:', error);
      setIsSearching(false);
    }
  };

  const handleCreateProject = async (e) => {
    e.preventDefault();
    try {
      const token = localStorage.getItem('token');
      await axios.post('http://localhost:5000/api/projects', newProject, {
        headers: { Authorization: `Bearer ${token}` }
      });
      setNewProject({ title: '', description: '', requiredSkills: '', teamSize: '', sector: '' });
      setShowForm(false);
      fetchProjects();
      setActiveTab('my'); // Switch to My Projects tab after creating a new project
    } catch (error) {
      console.error('Error creating project:', error);
    }
  };

  const handleJoinRequest = async (projectId) => {
    try {
      const token = localStorage.getItem('token');
      await axios.post(`http://localhost:5000/api/projects/${projectId}/request`, {}, {
        headers: { Authorization: `Bearer ${token}` }
      });
      
      // Update the local state to show pending status immediately
      setProjects(projects.map(project => 
        project.id === projectId 
          ? {...project, request_status: 'pending'} 
          : project
      ));
    } catch (error) {
      alert(error.response?.data?.error || 'Error sending request');
    }
  };

  // Handle filter change
  const handleFilterChange = (filterName, value) => {
    setFilters({
      ...filters,
      [filterName]: value
    });
  };

  // Apply filters to projects
  const applyFilters = (projectsList) => {
    let filtered = [...projectsList];
    
    // Apply category filter
    if (filters.category) {
      filtered = filtered.filter(project => project.sector === filters.category);
    }
    
    // Apply status filter if implemented in the backend
    if (filters.status !== 'All') {
      filtered = filtered.filter(project => project.status === filters.status);
    }
    
    // Apply creator filter
    if (filters.creator !== 'All') {
      if (filters.creator === 'Mine') {
        filtered = filtered.filter(project => project.created_by === user.id);
      }
      // Add other creator filters as needed
    }
    
    // Apply sorting
    switch (filters.sortBy) {
      case 'Newest First':
        filtered.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
        break;
      case 'Oldest First':
        filtered.sort((a, b) => new Date(a.created_at) - new Date(b.created_at));
        break;
      case 'Alphabetical (A-Z)':
        filtered.sort((a, b) => a.title.localeCompare(b.title));
        break;
      case 'Alphabetical (Z-A)':
        filtered.sort((a, b) => b.title.localeCompare(a.title));
        break;
      default:
        break;
    }
    
    return filtered;
  };

  // Filter projects based on active tab
  const filteredProjects = activeTab === 'all' 
    ? applyFilters(projects)
    : applyFilters(projects.filter(project => project.created_by === user.id));

  return (
    <Layout setToken={setToken}>
      <div className="dashboard-container">
        <div className="dashboard-header">
          <h1>Projects</h1>
          <div className="search-container">
            <input
              type="text"
              placeholder="Search projects by title, description, skills, or sector..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="search-input"
              onKeyPress={(e) => e.key === 'Enter' && searchProjects()}
            />
            <button 
              onClick={searchProjects}
              className="search-button"
              disabled={isSearching}
            >
              {isSearching ? '...' : 'Search'}
            </button>
            {searchQuery && (
              <button 
                onClick={() => {
                  setSearchQuery('');
                  fetchProjects();
                }}
                className="clear-search"
              >
                Clear
              </button>
            )}
          </div>
          
          <div className="dashboard-actions">
            <button 
              onClick={() => setShowForm(!showForm)}
              className="create-project-btn"
            >
              <span className="btn-icon">{showForm ? '✕' : '+'}</span>
              {showForm ? 'Cancel' : 'Create Project'}
            </button>
          </div>
        </div>

        <div className="main-content-wrapper">
          {/* Filters Sidebar */}
          <div className="filters-sidebar">
            <h3>Filters</h3>
            
            <div className="filter-section">
              <label>Category</label>
              <select 
                value={filters.category} 
                onChange={(e) => handleFilterChange('category', e.target.value)}
                className="filter-select"
              >
                <option value="">All Categories</option>
                {sectorOptions.map(sector => (
                  <option key={sector} value={sector}>{sector}</option>
                ))}
              </select>
            </div>
            
            <div className="filter-section">
              <label>Sort By</label>
              <select 
                value={filters.sortBy} 
                onChange={(e) => handleFilterChange('sortBy', e.target.value)}
                className="filter-select"
              >
                {sortOptions.map(option => (
                  <option key={option} value={option}>{option}</option>
                ))}
              </select>
            </div>
            
            <div className="filter-section">
              <label>Status</label>
              <select 
                value={filters.status} 
                onChange={(e) => handleFilterChange('status', e.target.value)}
                className="filter-select"
              >
                {statusOptions.map(status => (
                  <option key={status} value={status}>{status}</option>
                ))}
              </select>
            </div>
            
            <div className="filter-section">
              <label>Creator</label>
              <select 
                value={filters.creator} 
                onChange={(e) => handleFilterChange('creator', e.target.value)}
                className="filter-select"
              >
                <option value="All">All Creators</option>
                <option value="Mine">My Projects</option>
              </select>
            </div>
            
            <div className="filter-section">
              <label>Date Created</label>
              <input 
                type="date" 
                value={filters.dateCreated} 
                onChange={(e) => handleFilterChange('dateCreated', e.target.value)}
                className="filter-input"
              />
            </div>
          </div>

          {/* Main Content Area */}
          <div className="main-content">
            {/* Add Project Tabs */}
            <div className="project-tabs">
              <button 
                className={`tab-button ${activeTab === 'all' ? 'active' : ''}`}
                onClick={() => setActiveTab('all')}
              >
                All Projects
              </button>
              <button 
                className={`tab-button ${activeTab === 'my' ? 'active' : ''}`}
                onClick={() => setActiveTab('my')}
              >
                My Projects
              </button>
            </div>
            
            {showForm && (
              <form onSubmit={handleCreateProject} className="project-form animate-slideIn">
                <div className="form-row">
                  <div className="form-group-modern">
                    <label htmlFor="projectTitle">Project Title</label>
                    <input
                      id="projectTitle"
                      type="text"
                      placeholder="Enter project title"
                      value={newProject.title}
                      onChange={(e) => setNewProject({...newProject, title: e.target.value})}
                      className="modern-input"
                      required
                    />
                  </div>
                  <div className="form-group-modern">
                    <label htmlFor="projectSector">Project Category</label>
                    <select
                      id="projectSector"
                      value={newProject.sector}
                      onChange={(e) => setNewProject({...newProject, sector: e.target.value})}
                      className="modern-select"
                      required
                    >
                      <option value="" disabled>Select a category</option>
                      {sectorOptions.map(sector => (
                        <option key={sector} value={sector}>{sector}</option>
                      ))}
                    </select>
                  </div>
                </div>
                
                <div className="form-row">
                  <div className="form-group-modern">
                    <label htmlFor="projectSkills">Required Skills</label>
                    <input
                      id="projectSkills"
                      type="text"
                      placeholder="e.g. React, Node.js, Python"
                      value={newProject.requiredSkills}
                      onChange={(e) => setNewProject({...newProject, requiredSkills: e.target.value})}
                      className="modern-input"
                      required
                    />
                  </div>
                  <div className="form-group-modern">
                    <label htmlFor="teamSize">Team Size</label>
                    <select
                      id="teamSize"
                      value={newProject.teamSize}
                      onChange={(e) => setNewProject({...newProject, teamSize: e.target.value})}
                      className="modern-select"
                      required
                    >
                      <option value="" disabled>Select team size</option>
                      {[1,2,3,4,5,6,7,8,9,10].map(size => (
                        <option key={size} value={size}>{size} {size === 1 ? 'person' : 'people'}</option>
                      ))}
                      <option value="10+">More than 10</option>
                    </select>
                  </div>
                </div>
                
                <div className="form-group-modern">
                  <label htmlFor="projectDescription">Project Description</label>
                  <textarea
                    id="projectDescription"
                    placeholder="Describe your project, goals, and timeline"
                    value={newProject.description}
                    onChange={(e) => setNewProject({...newProject, description: e.target.value})}
                    className="modern-textarea"
                    required
                  />
                </div>
                
                <button type="submit" className="auth-button">
                  Create Project
                </button>
              </form>
            )}

            {/* Projects Grid */}
            <div className="projects-list">
              {filteredProjects.length === 0 && !isSearching && (
                <div className="tab-empty-state">
                  <h3>No projects found</h3>
                  <p>Try different search terms or filter settings</p>
                  <button 
                    className="create-project-button" 
                    onClick={() => {
                      setSearchQuery('');
                      setFilters({
                        category: '',
                        sortBy: 'Newest First',
                        status: 'All',
                        creator: 'All',
                        dateCreated: ''
                      });
                      fetchProjects();
                    }}
                  >
                    Clear Filters
                  </button>
                </div>
              )}
              
              {filteredProjects.map(project => (
                <div key={project.id} className="project-card-modern">
                  <div className="project-card-content">
                    <h3 className="project-card-title">{project.title}</h3>
                    {project.sector && (
                      <span className="sector-badge">{project.sector}</span>
                    )}
                    
                    <p className="project-description-truncate">
                      {project.description && project.description.length > 120 
                        ? `${project.description.substring(0, 120)}...`
                        : project.description}
                    </p>
                  
                    {project.requiredSkills && (
                      <div className="skills-row">
                        {project.requiredSkills.split(',').slice(0, 3).map((skill, index) => (
                          <span key={index} className="skill-pill">{skill.trim()}</span>
                        ))}
                        {project.requiredSkills.split(',').length > 3 && (
                          <span className="skill-pill more">+{project.requiredSkills.split(',').length - 3}</span>
                        )}
                      </div>
                    )}
                    
                    <div className="project-creator-info">
                      <Link to={`/profile/${project.created_by}`} className="creator-profile">
                        <div className="creator-avatar">
                          {project.creator_name?.charAt(0).toUpperCase()}
                        </div>
                        <span className="creator-name">{project.creator_name}</span>
                      </Link>
                    </div>
                  </div>
                  
                  <div className="card-actions">
                    {project.created_by !== user.id ? (
                      <>
                        {project.request_status === 'pending' ? (
                          <button className="join-button pending" disabled>
                            Pending Approval
                          </button>
                        ) : project.request_status === 'joined' ? (
                          <button className="join-button joined" disabled>
                            Joined
                          </button>
                        ) : project.request_status === 'rejected' ? (
                          <button className="join-button rejected" disabled>
                            Request Rejected
                          </button>
                        ) : (
                          <button onClick={() => handleJoinRequest(project.id)} className="join-button">
                            Request to Join
                          </button>
                        )}
                      </>
                    ) : (
                      <Link to={`/projects/${project.id}`} className="manage-button">
                        Manage Project
                      </Link>
                    )}
                    
                    <button 
                      onClick={() => {
                        setSelectedProject(project);
                        setShowDetailsModal(true);
                      }} 
                      className="view-details-link">
                      View Details
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>

      {/* Project Details Modal */}
      {showDetailsModal && selectedProject && (
        <div className="modal-overlay" onClick={() => setShowDetailsModal(false)}>
          <div className="modal" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h3>{selectedProject.title}</h3>
              <button className="modal-close-btn" onClick={() => setShowDetailsModal(false)}>×</button>
            </div>
            <div className="modal-content">
              {selectedProject.sector && (
                <div className="modal-detail-item">
                  <label>Category:</label>
                  <span>{selectedProject.sector}</span>
                </div>
              )}
              
              {selectedProject.description && (
                <div className="modal-detail-item">
                  <label>Description:</label>
                  <p>{selectedProject.description}</p>
                </div>
              )}
              
              {selectedProject.requiredSkills && (
                <div className="modal-detail-item">
                  <label>Required Skills:</label>
                  <div className="skill-tags">
                    {selectedProject.requiredSkills.split(',').map((skill, index) => (
                      <span key={index} className="skill-pill">{skill.trim()}</span>
                    ))}
                  </div>
                </div>
              )}
              
              {selectedProject.teamSize && (
                <div className="modal-detail-item">
                  <label>Team Size:</label>
                  <span>{selectedProject.teamSize} {selectedProject.teamSize === '1' ? 'person' : 'people'}</span>
                </div>
              )}
              
              <div className="modal-detail-item">
                <label>Created By:</label>
                <span>{selectedProject.creator_name}</span>
              </div>
              
              <div className="modal-detail-item">
                <label>Created On:</label>
                <span>{new Date(selectedProject.created_at).toLocaleDateString()}</span>
              </div>
              
              <div className="modal-actions">
                {selectedProject.created_by === user.id ? (
                  <Link to={`/projects/${selectedProject.id}`} className="modal-action-button manage-button">
                    Manage Project
                  </Link>
                ) : (
                  selectedProject.request_status !== 'joined' && selectedProject.request_status !== 'pending' && (
                    <button 
                      onClick={() => {
                        handleJoinRequest(selectedProject.id);
                        setShowDetailsModal(false);
                      }} 
                      className="modal-action-button join-button">
                      Request to Join
                    </button>
                  )
                )}
              </div>
            </div>
          </div>
        </div>
      )}
    </Layout>
  );
};

export default Dashboard;
