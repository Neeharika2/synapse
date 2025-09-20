import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { Link } from 'react-router-dom';
import Layout from './Layout';
import '../styles/profile.css';

const Profile = ({ setToken }) => {
  const [profile, setProfile] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [isEditing, setIsEditing] = useState(false);
  const [editedProfile, setEditedProfile] = useState({
    college: '',
    department: '',
    skills: '',
    bio: ''
  });
  const [notification, setNotification] = useState({ show: false, message: '', type: '' });

  useEffect(() => {
    fetchProfile();
  }, []);

  const fetchProfile = async () => {
    try {
      setLoading(true);
      const token = localStorage.getItem('token');
      const response = await axios.get('http://localhost:5000/api/profile', {
        headers: { Authorization: `Bearer ${token}` }
      });
      setProfile(response.data);
      
      // Initialize edit form
      setEditedProfile({
        college: response.data.college || '',
        department: response.data.department || '',
        skills: response.data.skills || '',
        bio: response.data.bio || ''
      });
      
      setLoading(false);
    } catch (error) {
      console.error('Error fetching profile:', error);
      setError('Failed to load profile data');
      setLoading(false);
    }
  };

  const handleEditToggle = () => {
    setIsEditing(!isEditing);
    
    // Reset form if canceling edit
    if (isEditing) {
      setEditedProfile({
        college: profile.college || '',
        department: profile.department || '',
        skills: profile.skills || '',
        bio: profile.bio || ''
      });
    }
  };

  const handleInputChange = (e) => {
    const { name, value } = e.target;
    setEditedProfile(prev => ({
      ...prev,
      [name]: value
    }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      const token = localStorage.getItem('token');
      await axios.put('http://localhost:5000/api/profile', editedProfile, {
        headers: { Authorization: `Bearer ${token}` }
      });
      
      // Update profile data
      const updatedProfile = { ...profile, ...editedProfile };
      setProfile(updatedProfile);
      
      // Exit edit mode
      setIsEditing(false);
      
      // Show success notification
      setNotification({
        show: true,
        message: 'Profile updated successfully!',
        type: 'success'
      });
      
      setTimeout(() => {
        setNotification({ show: false, message: '', type: '' });
      }, 3000);
    } catch (error) {
      console.error('Error updating profile:', error);
      setNotification({
        show: true,
        message: 'Failed to update profile. Please try again.',
        type: 'error'
      });
      
      setTimeout(() => {
        setNotification({ show: false, message: '', type: '' });
      }, 3000);
    }
  };

  if (loading) {
    return (
      <Layout setToken={setToken}>
        <div className="loading-spinner">Loading...</div>
      </Layout>
    );
  }

  if (error) {
    return (
      <Layout setToken={setToken}>
        <div className="error-message">{error}</div>
      </Layout>
    );
  }

  return (
    <Layout setToken={setToken}>
      {notification.show && (
        <div className={`notification ${notification.type}`}>
          {notification.message}
        </div>
      )}
      
      <div className="profile-container">
        <div className="profile-header">
          <div className="profile-avatar">
            {profile.name.charAt(0).toUpperCase()}
          </div>
          <div className="profile-title">
            <h1>{profile.name}</h1>
            <p className="profile-email">{profile.email}</p>
            {!isEditing && (
              <button 
                className="edit-profile-button" 
                onClick={handleEditToggle}
              >
                Edit Profile
              </button>
            )}
          </div>
        </div>
        
        {isEditing ? (
          <form onSubmit={handleSubmit} className="profile-edit-form">
            <div className="form-row">
              <div className="form-group">
                <label htmlFor="college">College/University</label>
                <input
                  type="text"
                  id="college"
                  name="college"
                  value={editedProfile.college}
                  onChange={handleInputChange}
                  placeholder="Enter your college/university"
                />
              </div>
              
              <div className="form-group">
                <label htmlFor="department">Department/Major</label>
                <input
                  type="text"
                  id="department"
                  name="department"
                  value={editedProfile.department}
                  onChange={handleInputChange}
                  placeholder="Enter your department or major"
                />
              </div>
            </div>
            
            <div className="form-group">
              <label htmlFor="skills">Skills (comma separated)</label>
              <input
                type="text"
                id="skills"
                name="skills"
                value={editedProfile.skills}
                onChange={handleInputChange}
                placeholder="e.g., React, Node.js, Python, Data Analysis"
              />
            </div>
            
            <div className="form-group">
              <label htmlFor="bio">Bio</label>
              <textarea
                id="bio"
                name="bio"
                value={editedProfile.bio}
                onChange={handleInputChange}
                placeholder="Tell others about yourself..."
                rows="4"
              ></textarea>
            </div>
            
            <div className="form-actions">
              <button type="submit" className="save-button">Save Changes</button>
              <button type="button" className="cancel-button" onClick={handleEditToggle}>Cancel</button>
            </div>
          </form>
        ) : (
          <div className="profile-details">
            <div className="profile-section">
              <h2>Personal Information</h2>
              <div className="profile-info-grid">
                <div className="info-item">
                  <span className="info-label">College/University:</span>
                  <span className="info-value">{profile.college || 'Not specified'}</span>
                </div>
                <div className="info-item">
                  <span className="info-label">Department/Major:</span>
                  <span className="info-value">{profile.department || 'Not specified'}</span>
                </div>
                <div className="info-item">
                  <span className="info-label">Member Since:</span>
                  <span className="info-value">{new Date(profile.created_at).toLocaleDateString()}</span>
                </div>
                <div className="info-item">
                  <span className="info-label">Credits:</span>
                  <span className="info-value">{profile.credits || 0} points</span>
                </div>
              </div>
            </div>
            
            {profile.bio && (
              <div className="profile-section">
                <h2>Bio</h2>
                <p className="profile-bio">{profile.bio}</p>
              </div>
            )}
            
            {profile.skills && (
              <div className="profile-section">
                <h2>Skills</h2>
                <div className="profile-skills">
                  {profile.skills.split(',').map((skill, index) => (
                    <span key={index} className="skill-tag">{skill.trim()}</span>
                  ))}
                </div>
              </div>
            )}
            
            <div className="profile-section">
              <div className="section-header">
                <h2>Project Statistics</h2>
              </div>
              <div className="stats-grid">
                <div className="stat-card">
                  <div className="stat-number">{profile.completed_projects}</div>
                  <div className="stat-label">Completed Projects</div>
                </div>
                <div className="stat-card">
                  <div className="stat-number">{profile.active_projects?.length || 0}</div>
                  <div className="stat-label">Active Projects</div>
                </div>
              </div>
            </div>
            
            {profile.active_projects && profile.active_projects.length > 0 && (
              <div className="profile-section">
                <h2>Active Projects</h2>
                <div className="active-projects-list">
                  {profile.active_projects.map(project => (
                    <Link to={`/projects/${project.id}`} key={project.id} className="project-card">
                      <h3>{project.title}</h3>
                      <p className="project-description">
                        {project.description?.length > 100 
                          ? project.description.substring(0, 100) + '...' 
                          : project.description}
                      </p>
                      <div className="project-meta">
                        <span>Created: {new Date(project.created_at).toLocaleDateString()}</span>
                        <span>By: {project.creator_name}</span>
                      </div>
                    </Link>
                  ))}
                </div>
              </div>
            )}
          </div>
        )}
      </div>
    </Layout>
  );
};

export default Profile;