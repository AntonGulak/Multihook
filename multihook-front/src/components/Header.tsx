import React, { useState, useEffect } from 'react';

declare global {
  interface Window {
    ethereum: any;
  }
}

const Header: React.FC = () => {
  const [account, setAccount] = useState<string | null>(null);

  const connectWallet = async () => {
    if (window.ethereum) {
      try {
        const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
        setAccount(accounts[0]);
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
        }
      }
    };

    checkAccount();
  }, [account]);

  const formatAddress = (address: string) => {
    return `${address.substring(0, 6)}...${address.substring(address.length - 4)}`;
  };

  return (
    <div className="header">
      {account ? (
        <div className="account-display">{formatAddress(account)}</div>
      ) : (
        <button className="connect-wallet-btn" onClick={connectWallet}>
          Подключить MetaMask
        </button>
      )}
    </div>
  );
};

export default Header;
