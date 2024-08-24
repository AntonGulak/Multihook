import React from 'react';
import { useNavigate } from 'react-router-dom';
import '../styles/app.css';  // Убедитесь, что стили подключены

interface ContractCardProps {
  contract: {
    id: string;
    address: string;
    network: string;
    name: string;
    description: string;
  };
}

const ContractCard: React.FC<ContractCardProps> = ({ contract }) => {
  const navigate = useNavigate();

  const handleCardClick = () => {
    navigate(`/contract/${contract.id}`);
  };

  return (
    <div className="contract-card" onClick={handleCardClick}>
      <h3>{contract.name}</h3>
      <p className="contract-address">{contract.address.substring(0, 6)}...{contract.address.substring(contract.address.length - 4)}</p>
      <p>{contract.network}</p>
      <p>{contract.description}</p>
    </div>
  );
}

export default ContractCard;
