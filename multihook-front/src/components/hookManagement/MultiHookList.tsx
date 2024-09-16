import React, { useState, useEffect, useMemo, useCallback, useRef } from 'react';
import HookCard from './MultiHookCard';
import { mockHooks } from '../../hooksMock';

import '../../styles/hookManagement/multiHookList.css';

export interface Hook {
  id: string;
  address: string;
  network: string;
  name: string;
  creationDate: string;
}

interface MultiHookListProps {
  onSelectHook: (hook: Hook) => void;
}

const MultiHookList: React.FC<MultiHookListProps> = ({ onSelectHook }) => {
  const [hooks, setHooks] = useState<Hook[]>([]);
  const [selectedNetworks, setSelectedNetworks] = useState<string[]>([]);
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('desc');
  const [searchQuery, setSearchQuery] = useState<string>('');
  const [isDropdownOpen, setIsDropdownOpen] = useState<boolean>(false);
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const dropdownRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    setTimeout(() => {
      setHooks(mockHooks);
      setIsLoading(false);
    }, 2000); 
  }, []);

  const uniqueNetworks = useMemo(() => {
    return Array.from(new Set(hooks.map(hook => hook.network)));
  }, [hooks]);

  const filteredHooks = useMemo(() => {
    return hooks
      .filter(hook => 
        (selectedNetworks.length === 0 || selectedNetworks.includes(hook.network)) &&
        (hook.name.toLowerCase().includes(searchQuery.toLowerCase()) || hook.address.toLowerCase().includes(searchQuery.toLowerCase()))
      )
      .sort((a, b) => sortOrder === 'asc'
        ? new Date(a.creationDate).getTime() - new Date(b.creationDate).getTime()
        : new Date(b.creationDate).getTime() - new Date(a.creationDate).getTime());
  }, [hooks, selectedNetworks, sortOrder, searchQuery]);

  const toggleNetworkSelection = useCallback((network: string) => {
    setSelectedNetworks(prevNetworks =>
      prevNetworks.includes(network)
        ? prevNetworks.filter(n => n !== network)
        : [...prevNetworks, network]
    );
  }, []);

  const handleSortOrderChange = useCallback((e: React.ChangeEvent<HTMLSelectElement>) => {
    setSortOrder(e.target.value as 'asc' | 'desc');
    setIsDropdownOpen(false);
  }, []);

  const handleSearchQueryChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    setSearchQuery(e.target.value);
  }, []);

  const toggleDropdown = useCallback(() => {
    setIsDropdownOpen(prevState => !prevState);
  }, []);

  const handleClickOutside = useCallback((event: MouseEvent) => {
    if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
      setIsDropdownOpen(false);
    }
  }, []);

  useEffect(() => {
    document.addEventListener('mousedown', handleClickOutside);
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, [handleClickOutside]);

  const resetFilters = useCallback(() => {
    setSelectedNetworks([]);
    setSortOrder('desc');
    setSearchQuery('');
    setIsDropdownOpen(false);
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
        <select onChange={handleSortOrderChange} value={sortOrder} className="sort-select">
          <option value="asc">Sort by Date (Asc)</option>
          <option value="desc">Sort by Date (Desc)</option>
        </select>
        <div className="dropdown" ref={dropdownRef}>
          <button className="dropdown-button" onClick={toggleDropdown}>
            Select Networks
            <span className="dropdown-arrow">&#9660;</span>
          </button>
          {isDropdownOpen && (
            <div className="dropdown-content">
              {uniqueNetworks.map(network => (
                <div
                  key={network}
                  className={`dropdown-item ${selectedNetworks.includes(network) ? 'selected' : ''}`}
                  onClick={() => toggleNetworkSelection(network)}
                >
                  {network}
                </div>
              ))}
            </div>
          )}
        </div>
        <button className="reset-button" onClick={resetFilters}>Reset</button>
      </div>
      <div className="hook-list">
        {isLoading ? (
          Array(9).fill(0).map((_, index) => (
            <div key={index} className="hook-card loading-placeholder" />
          ))
        ) : (
          filteredHooks.map(hook => (
            <HookCard 
              key={hook.id} 
              hook={hook} 
              onClick={() => onSelectHook(hook)} 
            />
          ))
        )}
      </div>
    </div>
  );
}

export default MultiHookList;
