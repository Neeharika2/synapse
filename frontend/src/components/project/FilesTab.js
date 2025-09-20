import React, { useState, useRef } from 'react';
import axios from 'axios';
import '../../styles/filesTab.css';

const FilesTab = ({ files, onUploadFile, projectId }) => {
  const [uploading, setUploading] = useState(false);
  const [uploadProgress, setUploadProgress] = useState(0);
  const fileInputRef = useRef(null);

  const handleFileChange = (e) => {
    const selectedFile = e.target.files[0];
    if (!selectedFile) return;
    
    handleUpload(selectedFile);
  };
  
  const handleUpload = async (file) => {
    setUploading(true);
    setUploadProgress(0);
    
    try {
      // Pass the file to the parent component
      await onUploadFile(file);
      
      // Reset the file input
      if (fileInputRef.current) {
        fileInputRef.current.value = '';
      }
    } catch (error) {
      console.error('Upload error:', error);
    } finally {
      setUploading(false);
      setUploadProgress(0);
    }
  };
  
  const handleDownload = async (fileId, fileName) => {
    try {
      const token = localStorage.getItem('token');
      
      // Use axios to get the file as a blob
      const response = await axios.get(
        `http://localhost:5000/api/files/${projectId}/download/${fileId}`,
        {
          headers: { Authorization: `Bearer ${token}` },
          responseType: 'blob'
        }
      );
      
      // Create a URL for the blob and trigger download
      const url = window.URL.createObjectURL(new Blob([response.data]));
      const link = document.createElement('a');
      link.href = url;
      link.setAttribute('download', fileName);
      document.body.appendChild(link);
      link.click();
      link.remove();
      window.URL.revokeObjectURL(url);
    } catch (error) {
      console.error('Download error:', error);
      alert('Failed to download file');
    }
  };
  
  const formatFileSize = (bytes) => {
    if (bytes < 1024) return bytes + ' bytes';
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
    return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
  };
  
  const formatDate = (dateString) => {
    const options = { year: 'numeric', month: 'short', day: 'numeric' };
    return new Date(dateString).toLocaleDateString(undefined, options);
  };

  return (
    <div className="files-tab">
      <div className="file-upload-section">
        <input 
          ref={fileInputRef}
          type="file" 
          id="fileInput"
          onChange={handleFileChange}
          disabled={uploading}
        />
        <label htmlFor="fileInput" className="file-upload-button">
          {uploading ? 'Uploading...' : 'Choose File'}
        </label>
        
        {uploading && (
          <div className="upload-progress">
            <div 
              className="progress-bar" 
              style={{ width: `${uploadProgress}%` }}
            ></div>
          </div>
        )}
      </div>
      
      <div className="files-list">
        <h3>Project Files</h3>
        {files.length === 0 ? (
          <p className="no-files-message">No files uploaded yet.</p>
        ) : (
          <table className="files-table">
            <thead>
              <tr>
                <th>Name</th>
                <th>Size</th>
                <th>Uploaded By</th>
                <th>Date</th>
                <th>Action</th>
              </tr>
            </thead>
            <tbody>
              {files.map(file => (
                <tr key={file.id}>
                  <td className="file-name">{file.file_name}</td>
                  <td>{formatFileSize(file.file_size)}</td>
                  <td>{file.uploaded_by_name}</td>
                  <td>{formatDate(file.uploaded_at)}</td>
                  <td>
                    <button 
                      className="download-button"
                      onClick={() => handleDownload(file.id, file.file_name)}
                    >
                      Download
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
};

export default FilesTab;
