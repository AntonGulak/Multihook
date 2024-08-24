import React from 'react';
import { useParams } from 'react-router-dom';

const ContractDetails: React.FC = () => {
  const { id } = useParams();

  return (
    <div className="contract-details">
      <h2>Детали смарт-контракта</h2>
      <p>Здесь будет подробная информация о контракте с ID: {id}</p>
    </div>
  );
}

export default ContractDetails;
