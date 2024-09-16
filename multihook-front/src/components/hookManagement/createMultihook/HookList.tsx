import React, { useState, useEffect, useMemo, useCallback, useRef } from 'react';
import { mockHooks } from '../../../hooksToolsMock';
import '../../../styles/hookManagement/hookList.css';
import HookCard, { HookCardProps } from './hookCard';

interface HookListProps {
  onSelectHooks: (hooks: HookCardProps['hook'][]) => void;
  onPrev: () => void;
  onNext: () => void;
}

const HookList: React.FC<HookListProps> = ({ onSelectHooks, onPrev, onNext }) => {
  const MAX_HOOKS = 16;
  const [hooks, setHooks] = useState<HookCardProps['hook'][]>([]);
  const [selectedHooks, setSelectedHooks] = useState<HookCardProps['hook'][]>([]);
  const [selectedCategories, setSelectedCategories] = useState<string[]>([]);
  const [searchQuery, setSearchQuery] = useState<string>('');
  const [isDropdownOpen, setIsDropdownOpen] = useState<boolean>(false);
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const dropdownRef = useRef<HTMLDivElement>(null);

  const categories = ["Decorator", "Core", "Dynamic fee"];

  useEffect(() => {
    setTimeout(() => {
      setHooks(mockHooks); 
      setIsLoading(false);
    }, 2000);
  }, []);

  const filteredHooks = useMemo(() => {
    return hooks
      .filter(hook => 
        (selectedCategories.length === 0 || selectedCategories.some(category => hook.description.includes(category))) &&
        (hook.name.toLowerCase().includes(searchQuery.toLowerCase()))
      );
  }, [hooks, selectedCategories, searchQuery]);


  const toggleCategorySelection = useCallback((category: string) => {
    setSelectedCategories(prevCategories =>
      prevCategories.includes(category)
        ? prevCategories.filter(c => c !== category)
        : [...prevCategories, category]
    );
  }, []);

  const toggleHookSelection = useCallback((hook: HookCardProps['hook']) => {
    setSelectedHooks(prevSelectedHooks => {
      const isAlreadySelected = prevSelectedHooks.some(selectedHook => selectedHook.id === hook.id);
      if (isAlreadySelected) {
        return prevSelectedHooks.filter(selectedHook => selectedHook.id !== hook.id);
      } else if (prevSelectedHooks.length < MAX_HOOKS) {
        return [...prevSelectedHooks, hook];
      } else {
        alert(`You can only select up to ${MAX_HOOKS} hooks.`);
        return prevSelectedHooks;
      }
    });
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


  useEffect(() => {
    onSelectHooks(selectedHooks);
  }, [selectedHooks, onSelectHooks]);

  const resetFilters = useCallback(() => {
    setSelectedCategories([]);
    setSearchQuery('');
    setIsDropdownOpen(false);
  }, []);

  return (
    <div className="hook-list-container">
      <div className="hook-selection-info">
        <p>Selected {selectedHooks.length} out of {MAX_HOOKS} possible hooks</p>
      </div>
      <div className="search-bar">
        <input 
          type="text" 
          placeholder="Search by name, creator or ID" 
          value={searchQuery}
          onChange={handleSearchQueryChange}
        />
      </div>
      <div className="hook-filter">
        <div className="dropdown" ref={dropdownRef}>
          <button className="dropdown-button" onClick={toggleDropdown}>
            Hook type
            <span className="dropdown-arrow">&#9660;</span>
          </button>
          {isDropdownOpen && (
            <div className="dropdown-content">
              {categories.map(category => (
                <div
                  key={category}
                  className={`dropdown-item ${selectedCategories.includes(category) ? 'selected' : ''}`}
                  onClick={() => toggleCategorySelection(category)}
                >
                  {category}
                </div>
              ))}
            </div>
          )}
        </div>
        <button className="reset-button" onClick={resetFilters}>Reset</button>
        <button className="nav-button" onClick={onPrev}>Prev</button>
        <button className="nav-button" onClick={onNext}>Next</button>
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
              onClick={() => toggleHookSelection(hook)}
              isSelected={selectedHooks.some(selectedHook => selectedHook.id === hook.id)}
            />
          ))
        )}
      </div>
    </div>
  );
}

export default HookList;
