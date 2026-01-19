# Synapse - Student Project Collaboration App

Synapse is a full-stack web application designed to help students collaborate on projects. It provides a comprehensive platform for team management, project organization, real-time communication, task tracking, file sharing, and meeting scheduling.

![Node.js](https://img.shields.io/badge/Node.js-339933?style=flat&logo=nodedotjs&logoColor=white)
![React](https://img.shields.io/badge/React-61DAFB?style=flat&logo=react&logoColor=black)
![MySQL](https://img.shields.io/badge/MySQL-4479A1?style=flat&logo=mysql&logoColor=white)
![Socket.io](https://img.shields.io/badge/Socket.io-010101?style=flat&logo=socketdotio&logoColor=white)

## 🚀 Features

### User Management
- **User Registration & Authentication** - Secure signup and login with JWT tokens
- **Email Verification** - Email-based authentication support
- **User Profiles** - Customizable profiles with college, department, skills, and bio

### Project Management
- **Create & Manage Projects** - Create projects with descriptions and status tracking
- **Project Requests** - Request to join projects with approval workflow
- **Project Teams** - Add team members with role-based access (owner/member)

### Team Collaboration
- **Team Creation** - Create teams and manage team members
- **Team Invitations** - Invite users to join teams with pending/accepted/rejected status
- **Team Projects** - Associate projects with teams for better organization

### Real-time Communication
- **Project Chat** - Real-time messaging within projects using Socket.io
- **Live Updates** - Instant message delivery to all project members

### Task Management
- **Create Tasks** - Add tasks with titles, descriptions, and due dates
- **Task Assignment** - Assign tasks to team members
- **Task Status** - Track progress with todo, in-progress, and done statuses

### File Sharing
- **File Upload** - Upload and share files within projects
- **File Management** - View uploaded files with metadata (size, type, uploader)

### Meeting Scheduler
- **Schedule Meetings** - Create meetings with date, time, and meeting links
- **Meeting Management** - Organize and track project meetings

## 🛠️ Tech Stack

### Frontend
- **React 18** - Modern UI library
- **React Router v6** - Client-side routing
- **Axios** - HTTP client for API requests
- **Socket.io Client** - Real-time communication

### Backend
- **Node.js** - JavaScript runtime
- **Express.js** - Web application framework
- **Socket.io** - Real-time bidirectional event-based communication
- **MySQL2** - Database driver
- **JWT** - JSON Web Tokens for authentication
- **bcryptjs** - Password hashing
- **Multer** - File upload handling
- **Nodemailer** - Email sending functionality

## 📁 Project Structure

```
synapse_app/
├── backend/
│   ├── config/
│   │   └── database.js         # Database configuration
│   ├── controllers/
│   │   └── chatController.js   # Chat logic controller
│   ├── middleware/
│   │   └── auth.js             # JWT authentication middleware
│   ├── routes/
│   │   ├── auth.js             # Authentication routes
│   │   ├── chat.js             # Chat routes
│   │   ├── emailAuth.js        # Email verification routes
│   │   ├── files.js            # File upload routes
│   │   ├── meetings.js         # Meeting routes
│   │   ├── profile.js          # User profile routes
│   │   ├── projects.js         # Project routes
│   │   ├── tasks.js            # Task routes
│   │   └── teams.js            # Team routes
│   ├── uploads/                # Uploaded files directory
│   ├── app.js
│   ├── database.sql            # Database schema
│   ├── db.js                   # Database connection
│   ├── package.json
│   └── server.js               # Main server entry point
│
└── frontend/
    ├── public/
    │   └── index.html
    ├── src/
    │   ├── components/
    │   │   ├── project/
    │   │   │   ├── ChatTab.js      # Project chat component
    │   │   │   ├── FilesTab.js     # Project files component
    │   │   │   ├── MeetingsTab.js  # Project meetings component
    │   │   │   └── TasksTab.js     # Project tasks component
    │   │   ├── Dashboard.js        # Main dashboard
    │   │   ├── Header.js           # Navigation header
    │   │   ├── Layout.js           # App layout wrapper
    │   │   ├── Login.js            # Login page
    │   │   ├── Profile.js          # User profile page
    │   │   ├── ProjectDetails.js   # Project details view
    │   │   ├── Register.js         # Registration page
    │   │   └── Teams.js            # Teams management page
    │   ├── styles/                 # Component styles
    │   ├── App.js                  # Main App component
    │   ├── App.css
    │   └── index.js
    ├── build/                      # Production build
    └── package.json
```

## 🔧 Installation & Setup

### Prerequisites
- Node.js (v14 or higher)
- MySQL Server
- npm or yarn

### Database Setup

1. Start your MySQL server

2. Run the database schema:
```bash
mysql -u your_username -p < backend/database.sql
```

Or manually execute the SQL in `backend/database.sql` using MySQL Workbench or CLI.

### Backend Setup

1. Navigate to the backend directory:
```bash
cd backend
```

2. Install dependencies:
```bash
npm install
```

3. Create a `.env` file in the backend directory:
```env
PORT=5000
DB_HOST=localhost
DB_USER=your_mysql_username
DB_PASSWORD=your_mysql_password
DB_NAME=synapse_db
JWT_SECRET=your_jwt_secret_key
EMAIL_USER=your_email@gmail.com
EMAIL_PASS=your_email_app_password
```

4. Start the backend server:
```bash
# Development mode with hot reload
npm run dev

# Production mode
npm start
```

The backend server will run on `http://localhost:5000`

### Frontend Setup

1. Navigate to the frontend directory:
```bash
cd frontend
```

2. Install dependencies:
```bash
npm install
```

3. Start the development server:
```bash
npm start
```

The frontend will run on `http://localhost:3000`

## 📡 API Endpoints

### Authentication
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/register` | Register a new user |
| POST | `/api/auth/login` | Login user |
| GET | `/api/auth/check-email` | Check if email exists |

### Projects
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/projects` | Get all projects |
| POST | `/api/projects` | Create a new project |
| GET | `/api/projects/:id` | Get project by ID |
| PUT | `/api/projects/:id` | Update project |
| DELETE | `/api/projects/:id` | Delete project |

### Teams
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/teams` | Get user's teams |
| POST | `/api/teams` | Create a new team |
| POST | `/api/teams/:id/invite` | Invite user to team |
| POST | `/api/teams/:id/respond` | Respond to invitation |

### Tasks
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/tasks/:projectId` | Get project tasks |
| POST | `/api/tasks` | Create a new task |
| PUT | `/api/tasks/:id` | Update task |
| DELETE | `/api/tasks/:id` | Delete task |

### Chat
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/chat/:projectId` | Get chat messages |
| POST | `/api/chat` | Send a message |

### Files
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/files/:projectId` | Get project files |
| POST | `/api/files/upload` | Upload a file |
| DELETE | `/api/files/:id` | Delete a file |

### Meetings
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/meetings/:projectId` | Get project meetings |
| POST | `/api/meetings` | Schedule a meeting |
| DELETE | `/api/meetings/:id` | Delete a meeting |

### Profile
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/profile` | Get user profile |
| PUT | `/api/profile` | Update user profile |

## 🔌 WebSocket Events

### Client Events
- `joinProject(projectId)` - Join a project's chat room
- `leaveProject(projectId)` - Leave a project's chat room
- `sendMessage({ projectId, userId, message })` - Send a chat message

### Server Events
- `newMessage(message)` - Broadcast new message to project room
- `error({ message })` - Error notification

## 🗄️ Database Schema

The application uses MySQL with the following main tables:
- `users` - User accounts
- `user_profiles` - Extended user information
- `projects` - Project details
- `project_requests` - Join requests for projects
- `project_team` - Project team members
- `teams` - Team information
- `team_members` - Team membership
- `team_invitations` - Pending team invitations
- `team_projects` - Team-project associations
- `chat_messages` - Project chat messages
- `project_files` - Uploaded files metadata
- `project_tasks` - Task management
- `project_meetings` - Scheduled meetings

## 🚀 Running in Production

### Build Frontend
```bash
cd frontend
npm run build
```

The build files will be generated in `frontend/build/`.

### Deploy
1. Serve the frontend build using a static file server or CDN
2. Run the backend server with a process manager like PM2:
```bash
npm install -g pm2
pm2 start backend/server.js --name synapse-backend
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

This project is open source and available under the [MIT License](LICENSE).

## 👥 Authors

- Student Project Collaboration Team

---

**Synapse** - Connecting Students, Powering Projects 🎓
