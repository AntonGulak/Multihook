import React from 'react';
import '../styles/sidebar.css';

interface SidebarProps {
  setCurrentSection: (section: string) => void;
}

const Sidebar: React.FC<SidebarProps> = ({ setCurrentSection }) => {
  return (
    <div className="sidebar">
      <h2>Multihook</h2>
      <ul>
        <li onClick={() => setCurrentSection('contractList')}>Мои DApps</li>
        <li onClick={() => setCurrentSection('createHook')}>Создать DApp</li>
        <li onClick={() => setCurrentSection('nextStep')}>Следующий Шаг</li>
      </ul>
    </div>
  );
};

export default Sidebar;
