import React, { useState, useEffect } from 'react';
import WalletModal from './WalletModal';
import '../../styles/metaMaskLogin.css';

declare global {
  interface Window {
    ethereum: any;
  }
}

interface MetaMaskLoginProps {
  onLogin: (account: string) => void;
}

const MetaMaskLogin: React.FC<MetaMaskLoginProps> = ({ onLogin }) => {
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [account, setAccount] = useState<string | null>(null);

  const connectMetaMask = async () => {
    if (window.ethereum) {
      try {
        const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
        setAccount(accounts[0]);
        onLogin(accounts[0]);
        setIsModalOpen(false);
      } catch (error) {
        console.error("Failed to connect to MetaMask", error);
      }
    } else {
      alert("MetaMask is not installed!");
    }
  };

  const connectWalletConnect = () => {
    alert("WalletConnect is not yet implemented.");
    setIsModalOpen(false);
  };

  useEffect(() => {
    if (window.ethereum) {
      const handleAccountsChanged = (accounts: string[]) => {
        if (accounts.length > 0) {
          setAccount(accounts[0]);
        }
      };

      window.ethereum.on('accountsChanged', handleAccountsChanged);

      return () => {
        if (window.ethereum.removeListener) {
          window.ethereum.removeListener('accountsChanged', handleAccountsChanged);
        }
      };
    }
  }, []);

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
