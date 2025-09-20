import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { useNavigate } from 'react-router-dom';
import '../styles/components.css';
import Layout from './Layout';

const Teams = ({ setToken }) => {
  const navigate = useNavigate();
  const [activeTab, setActiveTab] = useState('sent');
  const [sentRequests, setSentRequests] = useState([]);
  const [receivedRequests, setReceivedRequests] = useState([]);
  const [myTeams, setMyTeams] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [notification, setNotification] = useState({ show: false, message: '', type: '' });
  
  const showNotification = (message, type = 'success') => {
    setNotification({ show: true, message, type });
    setTimeout(() => {
      setNotification({ show: false, message: '', type: '' });
    }, 3000);
  };
  
  const fetchData = async (tab = activeTab) => {
    setLoading(true);
    try {
      const token = localStorage.getItem('token');
      let response;
      
      // Fetch data based on active tab
      if (tab === 'sent') {
        response = await axios.get('http://localhost:5000/api/teams/requests/sent', {
          headers: { Authorization: `Bearer ${token}` }
        });
        setSentRequests(response.data);
      } else if (tab === 'received') {
        response = await axios.get('http://localhost:5000/api/teams/requests/received', {
          headers: { Authorization: `Bearer ${token}` }
        });
        setReceivedRequests(response.data);
      } else if (tab === 'teams') {
        // Using the corrected endpoint
        response = await axios.get('http://localhost:5000/api/teams/user/teams', {
          headers: { Authorization: `Bearer ${token}` }
        });
        setMyTeams(response.data);
      }
      
      setError('');
    } catch (error) {
      console.error(`Error fetching ${tab} data:`, error);
      setError(`Failed to load ${tab} data. Please try again.`);
    } finally {
      setLoading(false);
    }
  };
  
  useEffect(() => {
    fetchData();
  }, [activeTab]);
  
  const handleAcceptRequest = async (requestId) => {
    try {
      const token = localStorage.getItem('token');
      await axios.post(`http://localhost:5000/api/teams/requests/${requestId}/accept`, {}, {
        headers: { Authorization: `Bearer ${token}` }
      });
      
      // Refresh received requests to get the latest status
      fetchData('received');
      
      // Show success message
      showNotification('Request accepted successfully');
    } catch (error) {
      console.error('Error accepting request:', error);
      let errorMessage = 'Failed to accept request. Please try again.';
      
      // Check if there's more specific error info from the server
      if (error.response && error.response.data && error.response.data.error) {
        errorMessage = error.response.data.error;
        if (error.response.data.details) {
          console.error('Details:', error.response.data.details);
        }
      }
      
      showNotification(errorMessage, 'error');
    }
  };
  
  const handleRejectRequest = async (requestId) => {
    try {
      const token = localStorage.getItem('token');
      await axios.post(`http://localhost:5000/api/teams/requests/${requestId}/reject`, {}, {
        headers: { Authorization: `Bearer ${token}` }
      });
      
      // Refresh received requests to get the latest status
      fetchData('received');
      
      // Show success message
      showNotification('Request rejected successfully');
    } catch (error) {
      console.error('Error rejecting request:', error);
      let errorMessage = 'Failed to reject request. Please try again.';
      
      // Check if there's more specific error info from the server
      if (error.response && error.response.data && error.response.data.error) {
        errorMessage = error.response.data.error;
      }
      
      showNotification(errorMessage, 'error');
    }
  };
  
  // Format date to be more readable
  const formatDate = (dateString) => {
    const options = { year: 'numeric', month: 'short', day: 'numeric' };
    return new Date(dateString).toLocaleDateString(undefined, options);
  };
  
  const renderSentRequests = () => {
    if (sentRequests.length === 0) {
      return (
        <div className="tab-empty-state">
          <h3>No Sent Requests</h3>
          <p>You haven't sent any join requests to projects yet.</p>
        </div>
      );
    }
    
    return (
      <div className="request-list">
        {sentRequests.map(request => (
          <div key={request.id} className="request-card">
            <div className="request-header">
              <h3>{request.title}</h3>
              <span className={`request-status status-${request.status}`}>
                {request.status.charAt(0).toUpperCase() + request.status.slice(1)}
              </span>
            </div>
            <p className="request-description">{request.description}</p>
            <div className="request-meta">
              <div className="meta-item">
                <svg className="meta-icon" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                </svg>
                <span>Sent on {formatDate(request.created_at)}</span>
              </div>
              <div className="meta-item">
                <svg className="meta-icon" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                </svg>
                <span>Owner: {request.creator_name}</span>
              </div>
            </div>
          </div>
        ))}
      </div>
    );
  };
  
  const renderReceivedRequests = () => {
    if (receivedRequests.length === 0) {
      return (
        <div className="tab-empty-state">
          <h3>No Received Requests</h3>
          <p>You haven't received any join requests for your projects yet.</p>
        </div>
      );
    }
    
    return (
      <div className="request-list">
        {receivedRequests.map(request => (
          <div key={request.id} className="request-card">
            <div className="request-header">
              <h3>{request.title}</h3>
              <span className={`request-status status-${request.status}`}>
                {request.status.charAt(0).toUpperCase() + request.status.slice(1)}
              </span>
            </div>
            <div className="request-meta">
              <div className="meta-item">
                <svg className="meta-icon" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                </svg>
                <span>From: {request.requester_name}</span>
              </div>
              <div className="meta-item">
                <svg className="meta-icon" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                </svg>
                <span>Received on {formatDate(request.created_at)}</span>
              </div>
              <div className="meta-item">
                <svg className="meta-icon" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
                </svg>
                <span>{request.requester_email}</span>
              </div>
            </div>
            {request.status === 'pending' && (
              <div className="request-actions">
                <button 
                  onClick={() => handleAcceptRequest(request.id)}
                  className="accept-button"
                >
                  Accept
                </button>
                <button 
                  onClick={() => handleRejectRequest(request.id)}
                  className="reject-button"
                >
                  Reject
                </button>
              </div>
            )}
          </div>
        ))}
      </div>
    );
  };
  
  const renderMyTeams = () => {
    if (myTeams.length === 0) {
      return (
        <div className="tab-empty-state">
          <h3>You're not part of any projects yet</h3>
          <p>Create a project or join an existing one to get started.</p>
        </div>
      );
    }
    
    return (
      <div className="teams-grid">
        {myTeams.map(team => (
          <div key={team.id} className="project-card">
            <h3>{team.title}</h3>
            <p className="project-description">{team.description}</p>
            
            <div className="project-tags">
              <span className={`role-badge ${team.role === 'owner' ? 'role-owner' : ''}`}>
                {team.role || 'Member'}
              </span>
              <span className="joined-date">
                {team.role === 'owner' ? 'Created: ' : 'Joined: '} 
                {new Date(team.joined_at).toLocaleDateString()}
              </span>
            </div>
            
            <div className="project-creator">
              <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"></path>
                <circle cx="12" cy="7" r="4"></circle>
              </svg>
              <span>
                {team.role === 'owner' ? <strong>Created by you</strong> : <><strong>Team Lead:</strong> {team.creator_name}</>}
              </span>
            </div>
            
            <button 
              className="view-team-button"
              onClick={() => navigate(`/projects/${team.id}`)}
            >
              View Project
            </button>
          </div>
        ))}
      </div>
    );
  };
  
  return (
    <Layout setToken={setToken}>
      <div className="teams-container">
        {notification.show && (
          <div className={`notification ${notification.type}`}>
            {notification.message}
          </div>
        )}
        
        <div className="tab-navigation teams-tabs">
          <button 
            className={`tab-button ${activeTab === 'sent' ? 'active' : ''}`}
            onClick={() => setActiveTab('sent')}
          >
            Sent Requests
          </button>
          <button 
            className={`tab-button ${activeTab === 'received' ? 'active' : ''}`}
            onClick={() => setActiveTab('received')}
          >
            Received Requests
          </button>
          <button 
            className={`tab-button ${activeTab === 'teams' ? 'active' : ''}`}
            onClick={() => setActiveTab('teams')}
          >
            My Projects
          </button>
        </div>
        
        <div className="tab-content">
          {loading ? (
            <div className="loading-state">
              <p>Loading...</p>
            </div>
          ) : error ? (
            <div className="error-state">
              <p>{error}</p>
              <button 
                onClick={() => fetchData()}
                className="retry-button"
              >
                Retry
              </button>
            </div>
          ) : (
            <>
              {activeTab === 'sent' && renderSentRequests()}
              {activeTab === 'received' && renderReceivedRequests()}
              {activeTab === 'teams' && renderMyTeams()}
            </>
          )}
        </div>
      </div>
    </Layout>
  );
};

export default Teams;
