import React, { useState, useMemo, useCallback } from 'react';
import Sidebar from '../sidebar/Sidebar';
import HookList, { Hook } from '../hookManagement/MultiHookList';
import MultiHookDetails from '../hookManagement/MultiHookDetails';
import CreateHook from '../hookManagement/createMultihook/CreateMultiHookMain';
import MetaMaskLogin from '../auth/MetaMaskLogin';

import '../../styles/appContainer/app.css';

declare global {
  interface Window {
    ethereum: any;
  }
}

const App: React.FC = () => {
  const [currentSection, setCurrentSection] = useState<'hookList' | 'hookDetails' | 'createHook' | 'nextStep'>('hookList');
  const [selectedHook, setSelectedHook] = useState<Hook | null>(null);
  const [account, setAccount] = useState<string | null>(null);
  const [sidebarWidth, setSidebarWidth] = useState(200);
  const [isDragging, setIsDragging] = useState(false);

  const handleLogin = useCallback((account: string) => {
    setAccount(account);
  }, []);

  const handleMouseDown = useCallback(() => {
    setIsDragging(true);
  }, []);

  const handleMouseMove = useCallback((e: React.MouseEvent) => {
    if (isDragging) {
      setSidebarWidth(prevWidth => Math.max(e.clientX, 150));
    }
  }, [isDragging]);

  const handleMouseUp = useCallback(() => {
    setIsDragging(false);
  }, []);

  const handleSelectHook = useCallback((hook: Hook) => {
    setSelectedHook(hook);
    setCurrentSection('hookDetails');
  }, []);

  const handleBackToList = useCallback(() => {
    setSelectedHook(null);
    setCurrentSection('hookList');
  }, []);

  const content = useMemo(() => {
    if (!account) {
      return <MetaMaskLogin onLogin={handleLogin} />;
    }

    switch (currentSection) {
      case 'hookList':
        return <HookList onSelectHook={handleSelectHook} />;
      case 'hookDetails':
        return selectedHook && <MultiHookDetails hook={selectedHook} onBack={handleBackToList} />;
      case 'createHook':
        return <CreateHook />;
      default:
        return null;
    }
  }, [account, currentSection, selectedHook, handleLogin, handleSelectHook, handleBackToList]);

  return (
    <div className="app-container" onMouseMove={handleMouseMove} onMouseUp={handleMouseUp}>
      <Sidebar setCurrentSection={setCurrentSection} width={sidebarWidth} />
      <div className="sidebar-resizer" onMouseDown={handleMouseDown} />
      <div className="content">
        {content}
      </div>
    </div>
  );
}

export default App;
