import React from 'react';
import '../../../styles/hookManagement/hookCard.css';

export type HookNames =
  | 'beforeInitialize'
  | 'afterInitialize'
  | 'beforeAddLiquidity'
  | 'afterAddLiquidity'
  | 'beforeRemoveLiquidity'
  | 'afterRemoveLiquidity'
  | 'beforeSwap'
  | 'afterSwap'
  | 'beforeDonate'
  | 'afterDonate';

export interface Hook {
  id: string;
  name: string;
  description: string;
  hooks: Record<HookNames, boolean>;
}

export interface HookCardProps {
  hook: Hook;
  isSelected: boolean;
  onClick: () => void;
  showHookPoints?: boolean;
}

const HookCard: React.FC<HookCardProps> = ({
  hook,
  isSelected,
  onClick,
  showHookPoints = false,
}) => {
  const activeHookPoints = Object.entries(hook.hooks)
    .filter(([_, value]) => value)
    .map(([key]) => key as HookNames);

  return (
    <div
      className={`hook-card ${isSelected ? 'selected' : ''}`}
      onClick={onClick}
    >
      <div className="hook-card-content">
        <h3 className="hook-name">{hook.name}</h3>
        <p className="hook-description">{hook.description}</p>
        {showHookPoints && activeHookPoints.length > 0 && (
          <div className="hook-points">
            {activeHookPoints.map(hookPoint => (
              <span key={hookPoint} className="hook-point">
                {hookPoint}
              </span>
            ))}
          </div>
        )}
      </div>
      {isSelected && <div className="selected-overlay">Selected</div>}
    </div>
  );
};

export default HookCard;
