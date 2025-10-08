import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import axios from 'axios';
import '../styles/components.css';

const Register = ({ setToken }) => {
  const navigate = useNavigate();
  const [formData, setFormData] = useState({ name: '', email: '', password: '' });
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [isOTPSent, setIsOTPSent] = useState(false);
  const [otp, setOTP] = useState('');
  
  // Add validation state
  const [isValidating, setIsValidating] = useState(false);
  const [validationError, setValidationError] = useState('');

  const handleInputChange = (e) => {
    const { name, value } = e.target;
    setFormData({ ...formData, [name]: value });
    
    // Clear validation errors when email changes
    if (name === 'email') {
      setValidationError('');
    }
  };

  const checkEmailExists = async (email) => {
    setIsValidating(true);
    try {
      // This endpoint should check if email exists and return appropriate response
      const response = await axios.post('http://localhost:5000/auth/check-email', { email });
      return response.data.exists;
    } catch (error) {
      if (error.response?.data?.error === 'Email already exists') {
        return true;
      }
      console.error('Error checking email:', error);
      return false;
    } finally {
      setIsValidating(false);
    }
  };

  const handleInitialSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    setValidationError('');
    
    try {
      // First check if email already exists
      const emailExists = await checkEmailExists(formData.email);
      
      if (emailExists) {
        setValidationError('This email is already registered. Please use a different email or login.');
        setLoading(false);
        return;
      }
      
      // If email doesn't exist, proceed with sending OTP
      const response = await axios.post('http://localhost:5000/auth/email-auth', formData);
      
      if (response.data.success) {
        setIsOTPSent(true);
        setError('');
      } else {
        setError(response.data.error || 'Failed to send verification code');
      }
    } catch (error) {
      console.error('Error during registration:', error);
      
      // Check for specific error about email already existing
      if (error.response?.data?.error === 'Email already exists' || 
          error.response?.data?.message === 'Email already exists' ||
          error.response?.status === 409) {
        setValidationError('This email is already registered. Please use a different email or login.');
      } else {
        setError(error.response?.data?.error || 'Failed to send verification code');
      }
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
            {loading ? 'Verifying...' : 'Verify & Complete Registration'}
          </button>
          
          <div className="auth-link">
            <button 
              type="button"
              className="text-button"
              onClick={() => setIsOTPSent(false)}
              disabled={loading}
            >
              Back to Registration
            </button>
          </div>
        </form>
      </div>
    );
  }

  // Initial registration form
  return (
    <div className="auth-container">
      <form onSubmit={handleInitialSubmit} className="auth-form animate-fadeIn">
        <h2>Create Account</h2>
        <p className="text-center">Enter your details to get started</p>
        
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
        
        {validationError && (
          <div className="error-modern">
            <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <circle cx="12" cy="12" r="10"></circle>
              <line x1="12" y1="8" x2="12" y2="12"></line>
              <line x1="12" y1="16" x2="12.01" y2="16"></line>
            </svg>
            {validationError} <Link to="/login" className="text-button-inline">Login here</Link>
          </div>
        )}
        
        <div className="form-group">
          <label htmlFor="name">Full Name</label>
          <div className="input-wrapper">
            <input
              id="name"
              type="text"
              name="name"
              placeholder="Enter your full name"
              value={formData.name}
              onChange={handleInputChange}
              required
            />
          </div>
        </div>

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
              className={validationError ? "input-error" : ""}
            />
          </div>
          {validationError && (
            <p className="input-error-text">{validationError}</p>
          )}
        </div>

        <div className="form-group">
          <label htmlFor="password">Password</label>
          <div className="input-wrapper">
            <input
              id="password"
              type="password"
              name="password"
              placeholder="Create a password"
              value={formData.password}
              onChange={handleInputChange}
              required
            />
          </div>
        </div>

        <button 
          type="submit" 
          className="auth-button"
          disabled={loading || isValidating}
        >
          {loading ? 'Sending verification code...' : 'Continue to Verify Email'}
        </button>
        
        <div className="auth-link">
          Already have an account? <Link to="/login">Sign in here</Link>
        </div>
      </form>
    </div>
  );
};

export default Register;

