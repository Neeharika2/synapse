import React from 'react';
import Header from './Header';
import '../styles/components.css';

const Layout = ({ children, setToken }) => {
  return (
    <div className="animate-fadeIn">
      <Header setToken={setToken} />

      <div className="main-content">
        {children}
      </div>
    </div>
  );
};

export default Layout;
