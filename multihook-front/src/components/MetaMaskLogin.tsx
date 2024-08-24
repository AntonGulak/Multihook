import React, { useState } from 'react';
import WalletModal from './WalletModal';
import '../styles/metaMaskLogin.css';

interface MetaMaskLoginProps {
  onLogin: (account: string) => void;
}

const MetaMaskLogin: React.FC<MetaMaskLoginProps> = ({ onLogin }) => {
  const [isModalOpen, setIsModalOpen] = useState(false);

  const connectMetaMask = async () => {
    if (window.ethereum) {
      try {
        const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
        onLogin(accounts[0]);
        setIsModalOpen(false);  // Закрываем модалку после успешного подключения
      } catch (error) {
        console.error("Failed to connect to MetaMask", error);
      }
    } else {
      alert("MetaMask is not installed!");
    }
  };

  const connectWalletConnect = () => {
    // Здесь будет логика подключения через WalletConnect
    alert("WalletConnect is not yet implemented.");
    setIsModalOpen(false);  // Закрываем модалку после попытки подключения
  };

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
