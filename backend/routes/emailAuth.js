const express = require('express');
const router = express.Router();
const nodemailer = require('nodemailer');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const db = require('../config/database');

// In-memory OTP store (in production, use Redis)
const otpStore = new Map();

// Create Nodemailer transporter using environment variables
const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST,
  port: parseInt(process.env.SMTP_PORT),
  secure: process.env.SMTP_PORT === '465', // true for 465, false for other ports
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS
  }
});

// Helper function to clean expired OTPs
const cleanExpiredOTPs = () => {
  const now = Date.now();
  for (const [email, data] of otpStore.entries()) {
    if (data.expires < now) {
      otpStore.delete(email);
    }
  }
};

// Route to register or login with email
router.post('/email-auth', async (req, res) => {
  try {
    const { name, email, password } = req.body;
    
    // Validate required fields
    if (!email || !email.includes('@')) {
      return res.status(400).json({ error: 'Valid email address is required' });
    }
    
    if (!name || !password) {
      return res.status(400).json({ error: 'Name and password are required' });
    }
    
    console.log('Email authentication attempt for:', email);
    
    // Check if user exists
    const checkUserQuery = 'SELECT * FROM users WHERE email = ?';
    
    db.query(checkUserQuery, [email], async (err, results) => {
      if (err) {
        console.error('Database error during email auth:', err);
        return res.status(500).json({ error: 'Database error' });
      }
      
      let userId;
      
      // If user doesn't exist, create a new account
      if (results.length === 0) {
        // Hash password for security
        const hashedPassword = await bcrypt.hash(password, 10);
        
        // Insert new user
        const createUserQuery = 'INSERT INTO users (name, email, password) VALUES (?, ?, ?)';
        
        db.query(createUserQuery, [name, email, hashedPassword], (createErr, createResult) => {
          if (createErr) {
            // Check for duplicate entry error (MySQL error code 1062)
            if (createErr.code === 'ER_DUP_ENTRY') {
              return res.status(409).json({ error: 'Email already exists' });
            }
            
            console.error('Error creating new user:', createErr);
            return res.status(500).json({ error: 'Failed to create new user' });
          }
          
          userId = createResult.insertId;
          
          // Create user profile
          db.query('INSERT INTO user_profiles (user_id) VALUES (?)', [userId]);
          
          // Generate and send OTP
          generateAndSendOTP(userId, name, email, res);
        });
      } else {
        // User exists, verify password
        const user = results[0];
        
        try {
          const passwordMatch = await bcrypt.compare(password, user.password);
          
          if (!passwordMatch) {
            return res.status(401).json({ error: 'Invalid email or password' });
          }
          
          // Password is correct, generate and send OTP
          generateAndSendOTP(user.id, user.name, email, res);
          
        } catch (bcryptError) {
          console.error('Password comparison error:', bcryptError);
          return res.status(500).json({ error: 'Authentication error' });
        }
      }
    });
  } catch (error) {
    console.error('Email auth error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// Helper function to generate and send OTP
function generateAndSendOTP(userId, name, email, res) {
  // Generate a 6-digit OTP
  const otp = Math.floor(100000 + Math.random() * 900000).toString();
  const expirationTime = Date.now() + (10 * 60 * 1000); // 10 minutes from now
  
  // Store OTP with user data (in production, use Redis)
  otpStore.set(email, {
    userId,
    name,
    otp,
    expires: expirationTime
  });
  
  // Clean up expired OTPs
  cleanExpiredOTPs();
  
  // Email template for OTP
  const emailHtml = `
    <!DOCTYPE html>
    <html>
    <head>
      <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }
        .content { background: #f9f9f9; padding: 30px; border-radius: 0 0 10px 10px; }
        .otp-code { font-size: 32px; font-weight: bold; letter-spacing: 5px; text-align: center; margin: 20px 0; color: #4a5568; }
        .footer { text-align: center; color: #666; font-size: 12px; margin-top: 30px; }
        .warning { background: #fff3cd; border: 1px solid #ffeaa7; color: #856404; padding: 15px; border-radius: 5px; margin: 20px 0; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>🔐 Synapse Login Verification</h1>
        </div>
        <div class="content">
          <h2>Hello ${name}!</h2>
          <p>Your verification code for Synapse is:</p>
          
          <div class="otp-code">${otp}</div>
          
          <div class="warning">
            <strong>⏰ Important:</strong> This code will expire in <strong>10 minutes</strong> for your security.
          </div>
          
          <p>If you didn't request this code, please ignore this email.</p>
        </div>
        <div class="footer">
          <p>This email was sent by Synapse • Secure Collaboration Platform</p>
        </div>
      </div>
    </body>
    </html>
  `;
  
  // Send OTP email
  const mailOptions = {
    from: {
      name: 'Synapse',
      address: process.env.SMTP_USER
    },
    to: email,
    subject: '🔐 Your Synapse Verification Code',
    html: emailHtml,
    text: `Hello ${name}!\n\nYour verification code for Synapse is: ${otp}\n\nThis code expires in 10 minutes.\n\nIf you didn't request this, ignore this email.`
  };
  
  transporter.sendMail(mailOptions, (mailError) => {
    if (mailError) {
      console.error('Error sending OTP email:', mailError);
      return res.status(500).json({ error: 'Failed to send verification code' });
    }
    
    // Respond with success
    res.json({
      success: true,
      message: 'Verification code sent to your email',
      expires_in: '10 minutes',
      email: email // Return email for the next step
    });
  });
}

// Route to verify OTP and issue JWT token
router.post('/verify-otp', (req, res) => {
  try {
    const { email, otp } = req.body;
    
    if (!email || !otp) {
      return res.status(400).json({ error: 'Email and verification code are required' });
    }
    
    // Clean expired OTPs first
    cleanExpiredOTPs();
    
    // Check if OTP exists and is valid
    const otpData = otpStore.get(email);
    
    if (!otpData) {
      return res.status(401).json({ error: 'Invalid or expired verification code' });
    }
    
    // Verify OTP
    if (otpData.otp !== otp) {
      return res.status(401).json({ error: 'Incorrect verification code' });
    }
    
    // OTP is valid, generate JWT for the user
    const payload = {
      userId: otpData.userId,
      email: email,
      name: otpData.name
    };
    
    // Generate JWT with same secret and expiry as existing auth
    const token = jwt.sign(payload, process.env.JWT_SECRET, { expiresIn: '7d' });
    
    // Remove the used OTP (one-time use)
    otpStore.delete(email);
    
    // Get user details to return
    db.query('SELECT id, name, email, created_at FROM users WHERE id = ?', [otpData.userId], (err, results) => {
      if (err || results.length === 0) {
        console.error('Error fetching user data:', err);
        return res.status(500).json({ error: 'Failed to retrieve user data' });
      }
      
      const userData = results[0];
      
      // Return the token and user data
      res.json({
        success: true,
        token,
        user: {
          id: userData.id,
          name: userData.name,
          email: userData.email,
          created_at: userData.created_at
        }
      });
    });
  } catch (error) {
    console.error('OTP verification error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// Cleanup function to run periodically
setInterval(cleanExpiredOTPs, 5 * 60 * 1000); // Clean every 5 minutes

module.exports = router;
