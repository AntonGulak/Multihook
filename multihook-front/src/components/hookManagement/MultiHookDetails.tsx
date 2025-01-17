import React from 'react';
import '../../styles/hookManagement/multiHookDetails.css';

interface MultiHookDetailsProps {
  hook: {
    id: string;
    address: string;
    network: string;
    name: string;
    creationDate: string;
  };
  onBack: () => void;
}

const MultiHookDetails: React.FC<MultiHookDetailsProps> = ({ hook, onBack }) => {
  return (
    <div className="hook-details-container">
      <button onClick={onBack} className="back-button">← Back</button>
      <h2>{hook.name}</h2>
      <p><strong>Address:</strong> {hook.address}</p>
      <p><strong>Network:</strong> {hook.network}</p>
      <p><strong>Creation Date:</strong> {hook.creationDate}</p>
      {/* Здесь можно добавить другие элементы управления контрактом */}
    </div>
  );
}

export default MultiHookDetails;
