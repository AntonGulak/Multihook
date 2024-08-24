import React, { useState, useEffect } from 'react';
import '../styles/metaMaskLogin.css';

declare global {
  interface Window {
    ethereum: any;
  }
}

interface MetaMaskLoginProps {
  onLogin: (account: string) => void;
}

const MetaMaskLogin: React.FC<MetaMaskLoginProps> = ({ onLogin }) => {
  const [account, setAccount] = useState<string | null>(null);

  const connectWallet = async () => {
    if (window.ethereum) {
      try {
        const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
        setAccount(accounts[0]);
        onLogin(accounts[0]);  // Сообщаем родительскому компоненту об успешной авторизации
      } catch (error) {
        console.error("Failed to connect to MetaMask", error);
      }
    } else {
      alert("MetaMask is not installed!");
    }
  };

  useEffect(() => {
    const checkAccount = async () => {
      if (window.ethereum && !account) {
        const accounts = await window.ethereum.request({ method: 'eth_accounts' });
        if (accounts.length > 0) {
          setAccount(accounts[0]);
          onLogin(accounts[0]);  // Сообщаем родительскому компоненту, что уже авторизованы
        }
      }
    };

    checkAccount();
  }, [account, onLogin]);

  return (
    <div className="metaMask-login">
      <button className="connect-wallet-btn" onClick={connectWallet}>
        Подключить MetaMask
      </button>
    </div>
  );
};

export default MetaMaskLogin;
