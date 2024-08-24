import React from 'react';
import '../../styles/walletModal.css';

interface WalletModalProps {
  onClose: () => void;
  onConnectMetaMask: () => void;
  onConnectWalletConnect: () => void;
}

const WalletModal: React.FC<WalletModalProps> = ({ onClose, onConnectMetaMask, onConnectWalletConnect }) => {
  return (
    <div className="modal-backdrop">
      <div className="modal-content">
        <div className="modal-header">
          <h2>Connect Wallet</h2>
          <button className="close-btn" onClick={onClose}>✖</button>
        </div>
        <div className="modal-body">
          <button className="wallet-btn" onClick={onConnectMetaMask}>
            <span>
              <img src="/assets/metamask-icon.svg" alt="MetaMask" />
              MetaMask
            </span>
          </button>
          <button className="wallet-btn" onClick={onConnectWalletConnect}>
            <span>
              <img src="/assets/walletconnect-icon.svg" alt="WalletConnect" />
              WalletConnect
            </span>
          </button>
        </div>
      </div>
    </div>
  );
};

export default WalletModal;
