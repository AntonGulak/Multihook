import React, { useState } from 'react';
import Sidebar from './Sidebar';
import HookList from './HookList';
import HookDetails from './HookDetails';
import MetaMaskLogin from './MetaMaskLogin';
import CreateHook from './CreateHook';
import NextStep from './NextStep';
import '../styles/app.css';

const App: React.FC = () => {
  const [currentSection, setCurrentSection] = useState('hookList');
  const [selectedHook, setSelectedHook] = useState<any | null>(null);
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

  const handleSelectHook = (hook: any) => {
    setSelectedHook(hook);
    setCurrentSection('hookDetails');
  };

  const handleBackToList = () => {
    setSelectedHook(null);
    setCurrentSection('hookList');
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
            {currentSection === 'hookList' && <HookList onSelectHook={handleSelectHook} />}
            {currentSection === 'hookDetails' && selectedHook && (
              <HookDetails hook={selectedHook} onBack={handleBackToList} />
            )}
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
