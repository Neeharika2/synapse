# Synapse - Student Collaboration Platform

Synapse is a full-stack platform designed to help students collaborate on projects, manage teams, share files, and communicate in real time. It features a robust backend (Node.js, Express, MySQL) and a modern cross-platform frontend (Flutter).

## Features
- User authentication (JWT, Google login)
- User profiles with academic and professional info
- Project creation, discovery, and management
- Team and membership management
- Task and todo tracking
- File sharing and management
- Real-time chat and notifications (Socket.IO)
- Meeting scheduling
- Responsive, cross-platform Flutter app

## Architecture
- **Backend:** Node.js, Express, MySQL, Socket.IO
- **Frontend:** Flutter (Dart), Provider for state management

### Database Tables
- `users`, `user_profiles`, `projects`, `project_members`, `tasks`, `messages`, `join_requests`, `project_todos`, `project_files`, `project_meetings`, `project_chat`

### Folder Structure
```
backend/   # Node.js/Express API
frontend/  # Flutter app
```

## How It Works
- The backend exposes RESTful APIs and real-time endpoints for all features.
- The frontend uses models (Dart classes) to represent backend data, providers for state management, and services for API/socket communication.
- Data flows from UI → Provider → Service → Backend and back, with models ensuring type safety.

## Getting Started
### Backend
1. Install dependencies:
   ```bash
   cd backend
   npm install
   ```
2. Configure `.env` with your MySQL credentials.
3. Start the server:
   ```bash
   npm run dev
   ```

### Frontend
1. Install Flutter dependencies:
   ```bash
   cd frontend
   flutter pub get
   ```
2. Run the app:
   ```bash
   flutter run
   ```

## Contributing
Pull requests are welcome! For major changes, please open an issue first to discuss what you would like to change.

## License
MIT
