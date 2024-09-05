import React from 'react';
import '../../styles/sidebar/sidebar.css';

interface SidebarProps {
  setCurrentSection: (section: 'hookList' | 'createHook' | 'nextStep') => void;
  width: number;
}

const Sidebar: React.FC<SidebarProps> = ({ setCurrentSection, width }) => {
  const fontSize = Math.max(14, width * 0.09);

  return (
    <div className="sidebar" style={{ width }}>
      <h2 style={{ fontSize: fontSize * 1.5 }}>Multihook</h2>
      <ul>
        <li style={{ fontSize }} onClick={() => setCurrentSection('hookList')}>Hooks</li>
        <li style={{ fontSize }} onClick={() => setCurrentSection('createHook')}>Create hook</li>
        {/* <li onClick={() => setCurrentSection('nextStep')}>Следующий Шаг</li> */}
      </ul>
    </div>
  );
};

export default Sidebar;
