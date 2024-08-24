import React, { useState, useEffect, useCallback } from 'react';
import WalletModal from './WalletModal';
import '../../styles/auth/metaMaskLogin.css';

declare global {
  interface Window {
    ethereum: any;
  }
}

interface MetaMaskLoginProps {
  onLogin: (account: string) => void;
}

const MetaMaskLogin: React.FC<MetaMaskLoginProps> = ({ onLogin }) => {
  const [isCheckingConnection, setIsCheckingConnection] = useState(true);
  const [isModalOpen, setIsModalOpen] = useState(false);

  const connectMetaMask = useCallback(async () => {
    if (!window.ethereum) {
      alert("MetaMask is not installed!");
      return;
    }

    try {
      const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
      if (accounts && accounts.length > 0) {
        onLogin(accounts[0]);
        setIsModalOpen(false);
      }
    } catch (error) {
      console.error("Failed to connect to MetaMask", error);
    }
  }, [onLogin]);

  const connectWalletConnect = useCallback(() => {
    alert("WalletConnect is not yet implemented.");
    setIsModalOpen(false);
  }, []);

  useEffect(() => {
    const checkIfConnected = async () => {
      if (window.ethereum) {
        try {
          const accounts = await window.ethereum.request({ method: 'eth_accounts' });
          if (accounts && accounts.length > 0) {
            onLogin(accounts[0]);
          }
        } catch (error) {
          console.error("Failed to check MetaMask connection", error);
        }
      }
      setIsCheckingConnection(false);  // Отключаем индикатор проверки подключения
    };

    checkIfConnected();

    const handleAccountsChanged = (accounts: string[]) => {
      if (accounts.length > 0) {
        onLogin(accounts[0]);
      }
    };

    if (window.ethereum) {
      window.ethereum.on('accountsChanged', handleAccountsChanged);
      return () => {
        window.ethereum.removeListener('accountsChanged', handleAccountsChanged);
      };
    }
  }, [onLogin]);

  if (isCheckingConnection) {
    // Показываем, например, загрузочный экран или ничего, пока идет проверка
    return null;
  }

  return (
    <div className="metaMask-login">
      <button className="connect-wallet-btn" onClick={() => setIsModalOpen(true)}>
        Connect Wallet
      </button>
      {isModalOpen && (
        <WalletModal
          onClose={() => setIsModalOpen(false)}
          onConnectMetaMask={connectMetaMask}
          onConnectWalletConnect={connectWalletConnect}
        />
      )}
    </div>
  );
};

export default MetaMaskLogin;
