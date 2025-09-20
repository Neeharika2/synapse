import React, { useState } from 'react';
import '../../styles/meetingsTab.css';

const MeetingsTab = ({ meetings, onCreateMeeting }) => {
  const [newMeeting, setNewMeeting] = useState({
    title: '',
    description: '',
    date: '',
    time: '',
    link: ''
  });
  
  const handleInputChange = (e) => {
    const { name, value } = e.target;
    setNewMeeting(prev => ({
      ...prev,
      [name]: value
    }));
  };
  
  const handleSubmit = (e) => {
    e.preventDefault();
    if (!newMeeting.title.trim() || !newMeeting.date || !newMeeting.time) return;
    
    onCreateMeeting(newMeeting);
    
    // Reset form
    setNewMeeting({
      title: '',
      description: '',
      date: '',
      time: '',
      link: ''
    });
  };
  
  const formatDate = (dateString) => {
    const options = { year: 'numeric', month: 'long', day: 'numeric' };
    return new Date(dateString).toLocaleDateString(undefined, options);
  };
  
  const formatTime = (timeString) => {
    return timeString.substring(0, 5);
  };
  
  const isUpcoming = (meeting) => {
    const meetingDate = new Date(`${meeting.meeting_date}T${meeting.meeting_time}`);
    return meetingDate > new Date();
  };
  
  // Sort meetings: upcoming first, then by date
  const sortedMeetings = [...meetings].sort((a, b) => {
    const aDate = new Date(`${a.meeting_date}T${a.meeting_time}`);
    const bDate = new Date(`${b.meeting_date}T${b.meeting_time}`);
    
    const aIsUpcoming = aDate > new Date();
    const bIsUpcoming = bDate > new Date();
    
    if (aIsUpcoming && !bIsUpcoming) return -1;
    if (!aIsUpcoming && bIsUpcoming) return 1;
    
    return aDate - bDate;
  });

  return (
    <div className="meetings-tab">
      <div className="meetings-form-container">
        <h3>Schedule a Meeting</h3>
        <form onSubmit={handleSubmit} className="meeting-form">
          <div className="form-group">
            <label htmlFor="title">Title*</label>
            <input
              type="text"
              id="title"
              name="title"
              value={newMeeting.title}
              onChange={handleInputChange}
              placeholder="Meeting title"
              required
            />
          </div>
          
          <div className="form-group">
            <label htmlFor="description">Description</label>
            <textarea
              id="description"
              name="description"
              value={newMeeting.description}
              onChange={handleInputChange}
              placeholder="Meeting agenda and notes"
              rows="3"
            ></textarea>
          </div>
          
          <div className="form-row">
            <div className="form-group">
              <label htmlFor="date">Date*</label>
              <input
                type="date"
                id="date"
                name="date"
                value={newMeeting.date}
                onChange={handleInputChange}
                required
              />
            </div>
            
            <div className="form-group">
              <label htmlFor="time">Time*</label>
              <input
                type="time"
                id="time"
                name="time"
                value={newMeeting.time}
                onChange={handleInputChange}
                required
              />
            </div>
          </div>
          
          <div className="form-group">
            <label htmlFor="link">Meeting Link</label>
            <input
              type="url"
              id="link"
              name="link"
              value={newMeeting.link}
              onChange={handleInputChange}
              placeholder="https://meet.google.com/..."
            />
          </div>
          
          <button type="submit" className="schedule-meeting-btn">Schedule Meeting</button>
        </form>
      </div>
      
      <div className="meetings-list">
        <h3>Scheduled Meetings</h3>
        {meetings.length === 0 ? (
          <p className="no-meetings-message">No meetings scheduled yet.</p>
        ) : (
          <div className="meeting-cards">
            {sortedMeetings.map(meeting => (
              <div 
                key={meeting.id} 
                className={`meeting-card ${isUpcoming(meeting) ? 'upcoming' : 'past'}`}
              >
                <h4>{meeting.title}</h4>
                
                <div className="meeting-details">
                  <div className="meeting-date-time">
                    <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                      <rect x="3" y="4" width="18" height="18" rx="2" ry="2"></rect>
                      <line x1="16" y1="2" x2="16" y2="6"></line>
                      <line x1="8" y1="2" x2="8" y2="6"></line>
                      <line x1="3" y1="10" x2="21" y2="10"></line>
                    </svg>
                    <span>{formatDate(meeting.meeting_date)} at {formatTime(meeting.meeting_time)}</span>
                  </div>
                  
                  <div className="meeting-organizer">
                    <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                      <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"></path>
                      <circle cx="12" cy="7" r="4"></circle>
                    </svg>
                    <span>Organized by: {meeting.organizer_name}</span>
                  </div>
                </div>
                
                {meeting.description && (
                  <p className="meeting-description">{meeting.description}</p>
                )}
                
                {meeting.meeting_link && isUpcoming(meeting) && (
                  <div className="meeting-actions">
                    <a 
                      href={meeting.meeting_link} 
                      target="_blank" 
                      rel="noopener noreferrer" 
                      className="join-meeting-btn"
                    >
                      Join Meeting
                    </a>
                  </div>
                )}
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};

export default MeetingsTab;
