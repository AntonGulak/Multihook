import React, { useState, useEffect } from 'react';
import HookCard from './HookCard';
import '../../styles/hookList.css';

interface Hook {
  id: string;
  address: string;
  network: string;
  name: string;
  creationDate: string;
}

interface HookListProps {
  onSelectHook: (hook: Hook) => void;
}

const HookList: React.FC<HookListProps> = ({ onSelectHook }) => {
  const [hooks, setHooks] = useState<Hook[]>([]);
  const [filter, setFilter] = useState<string>('All');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('desc');
  const [searchQuery, setSearchQuery] = useState<string>('');

  useEffect(() => {
    setHooks(mockHooks);
  }, []);

  const filteredHooks = hooks
    .filter(hook => 
      (filter === 'All' || hook.network === filter) &&
      (hook.name.toLowerCase().includes(searchQuery.toLowerCase()) || hook.address.toLowerCase().includes(searchQuery.toLowerCase()))
    )
    .sort((a, b) => sortOrder === 'asc'
      ? new Date(a.creationDate).getTime() - new Date(b.creationDate).getTime()
      : new Date(b.creationDate).getTime() - new Date(a.creationDate).getTime());

  return (
    <div className="hook-list-container">
      <div className="search-bar">
        <input 
          type="text" 
          placeholder="Search by name, creator or ID" 
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
        />
      </div>
      <div className="hook-filter">
        <select onChange={(e) => setFilter(e.target.value)} value={filter}>
          <option value="All">All Networks</option>
          <option value="Ethereum">Ethereum</option>
          <option value="Binance Smart Chain">Binance Smart Chain</option>
          <option value="Polygon">Polygon</option>
          {/* Add more options as needed */}
        </select>
        <select onChange={(e) => setSortOrder(e.target.value as 'asc' | 'desc')} value={sortOrder}>
          <option value="asc">Sort by Date (Asc)</option>
          <option value="desc">Sort by Date (Desc)</option>
        </select>
      </div>
      <div className="hook-list">
        {filteredHooks.map(hook => (
          <HookCard 
            key={hook.id} 
            hook={hook} 
            onClick={() => onSelectHook(hook)} // Передача функции для выбора контракта
          />
        ))}
      </div>
    </div>
  );
}

export default HookList;



const mockHooks = [
  {
    id: '1',
    address: '0x12ec0547a9943b3dd6ac5e7c4d2f669ea04d00f6',
    network: 'Ethereum',
    name: 'My First Hook',
    creationDate: '2024-08-01'
  },
  {
    id: '2',
    address: '0x34bead769df4f6eac4eac4eac769df7c76e7a7f5',
    network: 'Binance Smart Chain',
    name: 'My Second Hook',
    creationDate: '2024-07-31'
  },
  {
    id: '3',
    address: '0x3d9e68c69bc4d07a1d1d32f3e5e2e62f2b26e456',
    network: 'Polygon',
    name: 'My Third Hook',
    creationDate: '2024-07-25'
  },
  {
    id: '4',
    address: '0xf3e1ab054c3bbd2748e3e1f2b3c94f22cb9eec1a',
    network: 'Ethereum',
    name: 'My Fourth Hook',
    creationDate: '2024-07-20'
  },
  {
    id: '5',
    address: '0x85f5b7f22d9e6684c3b2c94d22cb9eec1a76e567',
    network: 'Arbitrum',
    name: 'My Fifth Hook',
    creationDate: '2024-07-18'
  },
  {
    id: '6',
    address: '0x9f3e1b3c74b6f4b2d32f3e2e6a1d1d4c5b7c3b2c',
    network: 'Binance Smart Chain',
    name: 'My Sixth Hook',
    creationDate: '2024-07-15'
  },
  {
    id: '7',
    address: '0x24c4c3b2e3e7b1c3d3c32e1f4c5b7b6f7d3b5c4e',
    network: 'Avalanche',
    name: 'My Seventh Hook',
    creationDate: '2024-07-12'
  },
  {
    id: '8',
    address: '0xe7b3c32f5b7c3b2e3f3e1b3c2e5d6a4b6f7c3d2e',
    network: 'Ethereum',
    name: 'My Eighth Hook',
    creationDate: '2024-07-10'
  },
  {
    id: '9',
    address: '0x4c3b2e5d7b6f3e1b3c2e5b7c3d2f4c5e6a7d3b1c',
    network: 'Polygon',
    name: 'My Ninth Hook',
    creationDate: '2024-07-08'
  },
  {
    id: '10',
    address: '0x3b2e7b6f3e1c3d2f4c5b7c3d2e1b3c2e6a7f4c5d',
    network: 'Binance Smart Chain',
    name: 'My Tenth Hook',
    creationDate: '2024-07-05'
  },
  {
    id: '11',
    address: '0x7b6f3e1c3d2f4c5b7c3d2e1b3c2e6a7f4c5d3b2e',
    network: 'Ethereum',
    name: 'My Eleventh Hook',
    creationDate: '2024-07-01'
  },
  {
    id: '12',
    address: '0xe1c3d2f4c5b7c3d2e1b3c2e6a7f4c5d3b2e5b7c',
    network: 'Arbitrum',
    name: 'My Twelfth Hook',
    creationDate: '2024-06-28'
  },
  {
    id: '13',
    address: '0x2f4c5b7c3d2e1b3c2e6a7f4c5d3b2e5b7c6a3e1f',
    network: 'Polygon',
    name: 'My Thirteenth Hook',
    creationDate: '2024-06-25'
  },
  {
    id: '14',
    address: '0x4c5b7c3d2e1b3c2e6a7f4c5d3b2e5b7c6a3e1f2f',
    network: 'Ethereum',
    name: 'My Fourteenth Hook',
    creationDate: '2024-06-22'
  },
  {
    id: '15',
    address: '0xb7c3d2e1b3c2e6a7f4c5d3b2e5b7c6a3e1f2f4c5',
    network: 'Binance Smart Chain',
    name: 'My Fifteenth Hook',
    creationDate: '2024-06-20'
  },
  {
    id: '16',
    address: '0x3d2e1b3c2e6a7f4c5d3b2e5b7c6a3e1f2f4c5b7c',
    network: 'Avalanche',
    name: 'My Sixteenth Hook',
    creationDate: '2024-06-18'
  },
  {
    id: '17',
    address: '0x2e1b3c2e6a7f4c5d3b2e5b7c6a3e1f2f4c5b7c3d',
    network: 'Polygon',
    name: 'My Seventeenth Hook',
    creationDate: '2024-06-15'
  },
  {
    id: '18',
    address: '0x1b3c2e6a7f4c5d3b2e5b7c6a3e1f2f4c5b7c3d2e',
    network: 'Ethereum',
    name: 'My Eighteenth Hook',
    creationDate: '2024-06-12'
  },
  {
    id: '19',
    address: '0x3c2e6a7f4c5d3b2e5b7c6a3e1f2f4c5b7c3d2e1b',
    network: 'Arbitrum',
    name: 'My Nineteenth Hook',
    creationDate: '2024-06-10'
  },
  {
    id: '20',
    address: '0xe6a7f4c5d3b2e5b7c6a3e1f2f4c5b7c3d2e1b3c2',
    network: 'Binance Smart Chain',
    name: 'My Twentieth Hook',
    creationDate: '2024-06-08'
  }
];