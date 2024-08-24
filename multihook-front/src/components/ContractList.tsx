import React, { useState, useEffect } from 'react';
import ContractCard from './ContractCard';
import '../styles/app.css';  // Убедитесь, что стили подключены

interface Contract {
  id: string;
  address: string;
  network: string;
  name: string;
  description: string;
}

const ContractList: React.FC = () => {
  const [contracts, setContracts] = useState<Contract[]>([]);

  useEffect(() => {
    // Заглушка для получения данных смарт-контрактов
    const mockContracts = [
      {
        id: '1',
        address: '0x12ec0547a9943b3dd6ac5e7c4d2f669ea04d00f6',
        network: 'Ethereum',
        name: 'My First Contract',
        description: 'This is a description of the first contract.'
      },
      {
        id: '2',
        address: '0x34bead769df4f6eac4eac4eac769df7c76e7a7f5',
        network: 'Binance Smart Chain',
        name: 'My Second Contract',
        description: 'This is a description of the second contract.'
      }
    ];
    setContracts(mockContracts);
  }, []);

  return (
    <div className="contract-list">
      {contracts.map(contract => (
        <ContractCard key={contract.id} contract={contract} />
      ))}
    </div>
  );
}

export default ContractList;
