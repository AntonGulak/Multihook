import React from 'react';
import '../../styles/appContainer/app.css';

interface MultiHookCardProps {
  hook: {
    id: string;
    address: string;
    network: string;
    name: string;
    creationDate: string;
  };
  onClick: () => void;
}

const HookCard: React.FC<MultiHookCardProps> = ({ hook, onClick }) => {
  return (
    <div className="hook-card" onClick={onClick}>
      <h3>{hook.name}</h3>
      <p className="hook-address">{hook.address.substring(0, 6)}...{hook.address.substring(hook.address.length - 4)}</p>
      <p>{hook.network}</p>
      <p className="hook-date">{hook.creationDate}</p>
    </div>
  );
}

export default HookCard;
