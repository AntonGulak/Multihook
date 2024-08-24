import React, { useState, useCallback } from 'react';
import '../../styles/hookManagement/createHook.css';

const CreateHook: React.FC = () => {
  const [network, setNetwork] = useState('');
  const [hookName, setHookName] = useState('');
  const [hookLogo, setHookLogo] = useState('');
  const [description, setDescription] = useState('');

  const handleSubmit = useCallback((e: React.FormEvent) => {
    e.preventDefault();
    if (!network || !hookName || !hookLogo || !description) {
      alert("Please fill in all fields");
      return;
    }

    // Закомментированная отправка данных на бэкенд
    /*
    fetch('/api/hooks', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ network, hookName, hookLogo, description })
    });
    */
    // Действие после отправки формы
  }, [network, hookName, hookLogo, description]);

  return (
    <div className="hook-form">
      <form onSubmit={handleSubmit}>
        <div className="form-group">
          <label htmlFor="network">Select Network</label>
          <select
            id="network"
            value={network}
            onChange={(e) => setNetwork(e.target.value)}
          >
            <option value="" disabled>Select Network</option>
            <option value="Ethereum">Ethereum</option>
            <option value="Arbitrum">Arbitrum</option>
            <option value="Binance Smart Chain">Binance Smart Chain</option>
          </select>
        </div>
        <div className="form-group">
          <label htmlFor="hookName">Hook name</label>
          <input
            id="hookName"
            type="text"
            value={hookName}
            onChange={(e) => setHookName(e.target.value)}
            placeholder="Enter Token Address"
          />
        </div>
        <div className="form-group">
          <label htmlFor="hookLogo">Hook logo</label>
          <input
            id="hookLogo"
            type="text"
            value={hookLogo}
            onChange={(e) => setHookLogo(e.target.value)}
            placeholder="Paste URL here"
          />
        </div>
        <div className="form-group">
          <label htmlFor="description">Short Project Description</label>
          <textarea
            id="description"
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            placeholder="Max 300 symbols"
            maxLength={300}
          />
        </div>
        <button type="submit" className="submit-btn">Next</button>
      </form>
    </div>
  );
};

export default CreateHook;
