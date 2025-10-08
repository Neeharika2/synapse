import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import axios from 'axios';
import '../styles/components.css';

const Login = ({ setToken }) => {
  const navigate = useNavigate();
  const [formData, setFormData] = useState({ email: '', password: '' });
  const [name, setName] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [isOTPSent, setIsOTPSent] = useState(false);
  const [otp, setOTP] = useState('');
  const [showLoginChoice, setShowLoginChoice] = useState(false);
  const [loginMethod, setLoginMethod] = useState('password');

  const handleInputChange = (e) => {
    const { name, value } = e.target;
    setFormData({ ...formData, [name]: value });
  };

  const handleInitialSubmit = (e) => {
    e.preventDefault();
    
    if (!formData.email) {
      setError('Email is required');
      return;
    }
    
    setError('');
    setShowLoginChoice(true);
  };

  const handlePasswordLogin = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);
    
    if (!formData.password) {
      setError('Password is required');
      setLoading(false);
      return;
    }
    
    try {
      const response = await axios.post('http://localhost:5000/api/auth/login', formData);
      localStorage.setItem('token', response.data.token);
      localStorage.setItem('user', JSON.stringify(response.data.user));
      setToken(response.data.token);
      navigate('/dashboard');
    } catch (error) {
      console.error('Login error:', error);
      setError(error.response?.data?.error || 'Login failed');
    } finally {
      setLoading(false);
    }
  };

  const handleSendOTP = async () => {
    setError('');
    setLoading(true);

    // For OTP login, we still need a name
    if (!name) {
      setError('Please enter your name to continue with OTP');
      setLoading(false);
      return;
    }

    try {
      // Send request to generate and email OTP
      const response = await axios.post('http://localhost:5000/auth/email-auth', {
        name: name,
        email: formData.email,
        password: formData.password || 'placeholder-for-otp-login' // Backend may require a password field
      });
      
      if (response.data.success) {
        setIsOTPSent(true);
        setError('');
      } else {
        setError(response.data.error || 'Failed to send verification code');
      }
    } catch (error) {
      console.error('Error sending OTP:', error);
      setError(error.response?.data?.error || 'Failed to send verification code');
    } finally {
      setLoading(false);
    }
  };

  const handleVerifyOTP = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    if (!otp) {
      setError('Please enter the verification code');
      setLoading(false);
      return;
    }

    try {
      // Verify OTP and get token
      const response = await axios.post('http://localhost:5000/auth/verify-otp', {
        email: formData.email,
        otp: otp
      });
      
      if (response.data.success) {
        // Store token and user data in localStorage
        localStorage.setItem('token', response.data.token);
        localStorage.setItem('user', JSON.stringify(response.data.user));
        
        // Update app state
        setToken(response.data.token);
        
        // Redirect to dashboard
        navigate('/dashboard');
      } else {
        setError(response.data.error || 'Verification failed');
      }
    } catch (error) {
      console.error('Error verifying OTP:', error);
      setError(error.response?.data?.error || 'Verification failed');
    } finally {
      setLoading(false);
    }
  };

  // OTP verification screen
  if (isOTPSent) {
    return (
      <div className="auth-container">
        <form onSubmit={handleVerifyOTP} className="auth-form animate-fadeIn">
          <h2>Verify Your Email</h2>
          <p className="text-center">
            We've sent a verification code to <strong>{formData.email}</strong>
          </p>
          
          {error && (
            <div className="error-modern">
              <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <circle cx="12" cy="12" r="10"></circle>
                <line x1="12" y1="8" x2="12" y2="12"></line>
                <line x1="12" y1="16" x2="12.01" y2="16"></line>
              </svg>
              {error}
            </div>
          )}
          
          <div className="form-group">
            <label htmlFor="otp">Verification Code</label>
            <div className="input-wrapper">
              <input
                id="otp"
                type="text"
                placeholder="Enter 6-digit code"
                value={otp}
                onChange={(e) => setOTP(e.target.value)}
                required
              />
            </div>
          </div>

          <button 
            type="submit" 
            className="auth-button"
            disabled={loading}
          >
            {loading ? 'Verifying...' : 'Verify & Log In'}
          </button>
          
          <div className="auth-link">
            <button 
              type="button"
              className="text-button"
              onClick={() => {
                setIsOTPSent(false);
                setShowLoginChoice(true);
              }}
              disabled={loading}
            >
              Back to Login Options
            </button>
          </div>
        </form>
      </div>
    );
  }

  // Login choice screen
  if (showLoginChoice) {
    return (
      <div className="auth-container">
        {loginMethod === 'password' ? (
          <form onSubmit={handlePasswordLogin} className="auth-form animate-fadeIn">
            <h2>Welcome Back</h2>
            <p className="text-center">Enter your password to continue</p>
            
            {error && (
              <div className="error-modern">
                <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <circle cx="12" cy="12" r="10"></circle>
                  <line x1="12" y1="8" x2="12" y2="12"></line>
                  <line x1="12" y1="16" x2="12.01" y2="16"></line>
                </svg>
                {error}
              </div>
            )}
            
            <div className="form-group">
              <label htmlFor="password">Password</label>
              <div className="input-wrapper">
                <input
                  id="password"
                  type="password"
                  name="password"
                  placeholder="Enter your password"
                  value={formData.password}
                  onChange={handleInputChange}
                  required
                />
              </div>
            </div>
            
            <button 
              type="submit" 
              className="auth-button"
              disabled={loading}
            >
              {loading ? 'Logging in...' : 'Log In'}
            </button>
            
            <div className="auth-divider">
              <span>or</span>
            </div>
            
            <button 
              type="button" 
              className="auth-button otp-button"
              onClick={() => setLoginMethod('otp')}
            >
              Use Verification Code Instead
            </button>
            
            <div className="auth-link">
              <button 
                type="button"
                className="text-button"
                onClick={() => {
                  setShowLoginChoice(false);
                  setFormData({ ...formData, password: '' });
                }}
              >
                Back
              </button>
            </div>
          </form>
        ) : (
          <div className="auth-form animate-fadeIn">
            <h2>Email Verification</h2>
            <p className="text-center">Confirm your name to receive a verification code</p>
            
            {error && (
              <div className="error-modern">
                <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <circle cx="12" cy="12" r="10"></circle>
                  <line x1="12" y1="8" x2="12" y2="12"></line>
                  <line x1="12" y1="16" x2="12.01" y2="16"></line>
                </svg>
                {error}
              </div>
            )}
            
            <div className="form-group">
              <label htmlFor="name">Your Name</label>
              <div className="input-wrapper">
                <input
                  id="name"
                  type="text"
                  placeholder="Enter your name"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  required
                />
              </div>
            </div>
            
            <button 
              type="button" 
              className="auth-button otp-button"
              onClick={handleSendOTP}
              disabled={loading}
            >
              {loading ? 'Sending...' : 'Send Verification Code'}
            </button>
            
            <div className="auth-divider">
              <span>or</span>
            </div>
            
            <button 
              type="button" 
              className="auth-button password-button"
              onClick={() => setLoginMethod('password')}
            >
              Use Password Instead
            </button>
            
            <div className="auth-link">
              <button 
                type="button"
                className="text-button"
                onClick={() => {
                  setShowLoginChoice(false);
                  setName('');
                }}
              >
                Back
              </button>
            </div>
          </div>
        )}
      </div>
    );
  }

  // Initial login form
  return (
    <div className="auth-container">
      <form onSubmit={handleInitialSubmit} className="auth-form animate-fadeIn">
        <h2>Welcome to Synapse</h2>
        <p className="text-center">Enter your email to continue</p>
        
        {error && (
          <div className="error-modern">
            <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <circle cx="12" cy="12" r="10"></circle>
              <line x1="12" y1="8" x2="12" y2="12"></line>
              <line x1="12" y1="16" x2="12.01" y2="16"></line>
            </svg>
            {error}
          </div>
        )}
        
        <div className="form-group">
          <label htmlFor="email">Email Address</label>
          <div className="input-wrapper">
            <input
              id="email"
              type="email"
              name="email"
              placeholder="Enter your email"
              value={formData.email}
              onChange={handleInputChange}
              required
            />
          </div>
        </div>

        <button 
          type="submit" 
          className="auth-button"
          disabled={loading}
        >
          Continue
        </button>
        
        <div className="auth-link">
          Don't have an account? <Link to="/register">Register here</Link>
        </div>
      </form>
    </div>
  );
};

export default Login;
       


