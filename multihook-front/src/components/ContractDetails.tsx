import React from 'react';
import '../styles/contractDetails.css';

interface ContractDetailsProps {
  contract: {
    id: string;
    address: string;
    network: string;
    name: string;
    creationDate: string;
  };
  onBack: () => void;
}

const ContractDetails: React.FC<ContractDetailsProps> = ({ contract, onBack }) => {
  return (
    <div className="contract-details-container">
      <button onClick={onBack} className="back-button">← Back</button>
      <h2>{contract.name}</h2>
      <p><strong>Address:</strong> {contract.address}</p>
      <p><strong>Network:</strong> {contract.network}</p>
      <p><strong>Creation Date:</strong> {contract.creationDate}</p>
      {/* Здесь можно добавить другие элементы управления контрактом */}
    </div>
  );
}

export default ContractDetails;
