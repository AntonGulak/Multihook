import React, { useState, useEffect, useMemo, useCallback } from 'react';
import HookCard from './HookCard';
import { mockHooks } from '../../hooksMock';

import '../../styles/hookManagement/hookList.css';

export interface Hook {
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

  const filteredHooks = useMemo(() => {
    return hooks
      .filter(hook => 
        (filter === 'All' || hook.network === filter) &&
        (hook.name.toLowerCase().includes(searchQuery.toLowerCase()) || hook.address.toLowerCase().includes(searchQuery.toLowerCase()))
      )
      .sort((a, b) => sortOrder === 'asc'
        ? new Date(a.creationDate).getTime() - new Date(b.creationDate).getTime()
        : new Date(b.creationDate).getTime() - new Date(a.creationDate).getTime());
  }, [hooks, filter, sortOrder, searchQuery]);

  const handleFilterChange = useCallback((e: React.ChangeEvent<HTMLSelectElement>) => {
    setFilter(e.target.value);
  }, []);

  const handleSortOrderChange = useCallback((e: React.ChangeEvent<HTMLSelectElement>) => {
    setSortOrder(e.target.value as 'asc' | 'desc');
  }, []);

  const handleSearchQueryChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    setSearchQuery(e.target.value);
  }, []);

  return (
    <div className="hook-list-container">
      <div className="search-bar">
        <input 
          type="text" 
          placeholder="Search by name, creator or ID" 
          value={searchQuery}
          onChange={handleSearchQueryChange}
        />
      </div>
      <div className="hook-filter">
        <select onChange={handleFilterChange} value={filter}>
          <option value="All">All Networks</option>
          <option value="Ethereum">Ethereum</option>
          <option value="Binance Smart Chain">Binance Smart Chain</option>
          <option value="Polygon">Polygon</option>
        </select>
        <select onChange={handleSortOrderChange} value={sortOrder}>
          <option value="asc">Sort by Date (Asc)</option>
          <option value="desc">Sort by Date (Desc)</option>
        </select>
      </div>
      <div className="hook-list">
        {filteredHooks.map(hook => (
          <HookCard 
            key={hook.id} 
            hook={hook} 
            onClick={() => onSelectHook(hook)} 
          />
        ))}
      </div>
    </div>
  );
}

export default HookList;
