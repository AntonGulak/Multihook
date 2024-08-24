import React from 'react';
import '../styles/sidebar.css';

interface SidebarProps {
  setCurrentSection: (section: string) => void;
  width: number;
}

const Sidebar: React.FC<SidebarProps> = ({ setCurrentSection, width }) => {
  // Рассчитываем размер шрифта на основе ширины
  const fontSize = Math.max(14, width * 0.08); // минимальный размер шрифта - 14px

  return (
    <div className="sidebar" style={{ width }}>
      <h2 style={{ fontSize: fontSize * 1.2 }}>Multihook</h2>
      <ul>
        <li style={{ fontSize }} onClick={() => setCurrentSection('hookList')}>Hooks</li>
        <li style={{ fontSize }} onClick={() => setCurrentSection('createHook')}>Create hook</li>
        {/* <li onClick={() => setCurrentSection('nextStep')}>Следующий Шаг</li> */}
      </ul>
    </div>
  );
};

export default Sidebar;
