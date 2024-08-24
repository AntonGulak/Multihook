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

  const handleLogin = (account: string) => {
    setAccount(account);
  };

  const renderContent = () => {
    if (!account) {
      return <MetaMaskLogin onLogin={handleLogin} />;
    }

    switch (currentSection) {
      case 'contractList':
        return <ContractList />;
      case 'createHook':
        return <CreateHook />;
      case 'nextStep':
        return <NextStep />;
      default:
        return <ContractList />;
    }
  };

  return (
    <div className="app-container">
      <Sidebar setCurrentSection={setCurrentSection} />
      <div className="content">
        {renderContent()}
      </div>
    </div>
  );
}

export default App;
