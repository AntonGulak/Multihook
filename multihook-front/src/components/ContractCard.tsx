import React from 'react';
import '../styles/app.css';

interface ContractCardProps {
  contract: {
    id: string;
    address: string;
    network: string;
    name: string;
    creationDate: string;
  };
  onClick: () => void; // Добавляем onClick как пропс
}

const ContractCard: React.FC<ContractCardProps> = ({ contract, onClick }) => {
  return (
    <div className="contract-card" onClick={onClick}>
      <h3>{contract.name}</h3>
      <p className="contract-address">{contract.address.substring(0, 6)}...{contract.address.substring(contract.address.length - 4)}</p>
      <p>{contract.network}</p>
      <p className="contract-date">{contract.creationDate}</p>
    </div>
  );
}

export default ContractCard;
