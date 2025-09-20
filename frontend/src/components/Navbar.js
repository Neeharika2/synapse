import React from 'react';
import { Link, useLocation } from 'react-router-dom';
import '../styles/components.css';

const Navbar = ({ setToken }) => {
  const location = useLocation();
  const currentPath = location.pathname;
  const user = JSON.parse(localStorage.getItem('user'));
  
  const handleLogout = () => {
    localStorage.removeItem('token');
    localStorage.removeItem('user');
    setToken(null);
  };
  
  return (
    <>
      <div className="dashboard-header-wrapper">
        <header className="dashboard-header">
          <div>
            <h1>Welcome, {user?.name}</h1>
            <p className="text-light">Collaborate and build amazing projects</p>
          </div>
          <div className="header-actions">
            <button onClick={handleLogout} className="btn-secondary">
              <span className="btn-icon">🚪</span>
              Logout
            </button>
          </div>
        </header>
      </div>
      
      <nav className="main-nav">
        <div className="nav-container">
          <Link to="/dashboard" className="nav-logo">
            Synapse
          </Link>
          <ul className="nav-links">
            <li className="nav-item">
              <Link to="/dashboard" className={`nav-link ${currentPath === '/dashboard' ? 'active' : ''}`}>
                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
                </svg>
                Projects
              </Link>
            </li>
            <li className="nav-item">
              <Link to="/teams" className={`nav-link ${currentPath === '/teams' ? 'active' : ''}`}>
                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
                </svg>
                Teams
              </Link>
            </li>
           
          </ul>
        </div>
      </nav>
    </>
  );
};

export default Navbar;
