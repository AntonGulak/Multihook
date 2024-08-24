import React, { useState } from 'react';
import Sidebar from './Sidebar';
import ContractList from './ContractList';
import MetaMaskLogin from './MetaMaskLogin';
import CreateHook from '../pages/CreateHook';
import NextStep from '../pages/NextStep';
import '../styles/app.css';

const App: React.FC = () => {
  const [currentSection, setCurrentSection] = useState('contractList');
  const [account, setAccount] = useState<string | null>(null);
  const [sidebarWidth, setSidebarWidth] = useState(200); // начальная ширина сайдбара
  const [isDragging, setIsDragging] = useState(false);

  const handleLogin = (account: string) => {
    setAccount(account);
  };

  const handleMouseDown = () => {
    setIsDragging(true);
  };

  const handleMouseMove = (e: React.MouseEvent) => {
    if (isDragging) {
      setSidebarWidth(Math.max(e.clientX, 150)); // минимальная ширина сайдбара 150px
    }
  };

  const handleMouseUp = () => {
    setIsDragging(false);
  };

  return (
    <div
      className="app-container"
      onMouseMove={handleMouseMove}
      onMouseUp={handleMouseUp}
    >
      <Sidebar setCurrentSection={setCurrentSection} width={sidebarWidth} />
      <div
        className="sidebar-resizer"
        onMouseDown={handleMouseDown}
      />
      <div className="content">
        {account ? (
          <>
            {currentSection === 'contractList' && <ContractList />}
            {currentSection === 'createHook' && <CreateHook />}
            {currentSection === 'nextStep' && <NextStep />}
          </>
        ) : (
          <MetaMaskLogin onLogin={handleLogin} />
        )}
      </div>
    </div>
  );
}

export default App;
