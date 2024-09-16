import React, { useState } from 'react';
import { Hook, HookNames } from './hookCard';
import '../../../styles/hookManagement/hookSequenceEditor.css';

interface HookSequenceEditorProps {
  selectedHooks: Hook[];
  onPrev: () => void;
  onSave: (orderedHooks: Hook[]) => void;
}

const hookPoints: HookNames[] = [
  'beforeInitialize',
  'afterInitialize',
  'beforeAddLiquidity',
  'afterAddLiquidity',
  'beforeRemoveLiquidity',
  'afterRemoveLiquidity',
  'beforeSwap',
  'afterSwap',
  'beforeDonate',
  'afterDonate',
];

type HookPoint = HookNames;

const HookSequenceEditor: React.FC<HookSequenceEditorProps> = ({ selectedHooks, onPrev, onSave }) => {
  const [hookSequences, setHookSequences] = useState<Record<HookPoint, Hook[]>>(() => {
    const sequences: Record<HookPoint, Hook[]> = {} as any;
    hookPoints.forEach(hookPoint => {
      sequences[hookPoint] = selectedHooks.filter(hook => hook.hooks[hookPoint]);
    });
    return sequences;
  });

  const moveUp = (hookPoint: HookPoint, index: number) => {
    if (index === 0) return; // Нельзя двигать выше первого элемента
    const items = Array.from(hookSequences[hookPoint]);
    const [movedItem] = items.splice(index, 1);
    items.splice(index - 1, 0, movedItem); // Перемещаем на одну позицию выше
    setHookSequences(prevSequences => ({
      ...prevSequences,
      [hookPoint]: items,
    }));
  };

  const moveDown = (hookPoint: HookPoint, index: number) => {
    const items = Array.from(hookSequences[hookPoint]);
    if (index === items.length - 1) return; // Нельзя двигать ниже последнего элемента
    const [movedItem] = items.splice(index, 1);
    items.splice(index + 1, 0, movedItem); // Перемещаем на одну позицию ниже
    setHookSequences(prevSequences => ({
      ...prevSequences,
      [hookPoint]: items,
    }));
  };

  const handleSave = () => {
    const orderedHooks: Hook[] = [];
    hookPoints.forEach(hookPoint => {
      orderedHooks.push(...hookSequences[hookPoint]);
    });
    onSave(orderedHooks);
  };

  return (
    <div className="hook-sequence-container">
      <h2>Configure Hook Sequences</h2>
      <div className="hook-points-container">
        {hookPoints.map(hookPoint => {
          const hooksForPoint = hookSequences[hookPoint];
          if (hooksForPoint.length === 0) return null;
          return (
            <div key={hookPoint} className="hook-point-card">
              <div className="hook-point-title">{hookPoint}</div>
              <div className="hook-point-list">
                {hooksForPoint.map((hook, index) => (
                  <div key={hook.id} className="hook-item">
                    <h4>{hook.name}</h4>
                    {hooksForPoint.length > 1 && (
                      <div className="arrow-buttons">
                        <button className="arrow-up" onClick={() => moveUp(hookPoint, index)} disabled={index === 0}>
                          ↑
                        </button>
                        <button className="arrow-down" onClick={() => moveDown(hookPoint, index)} disabled={index === hooksForPoint.length - 1}>
                          ↓
                        </button>
                      </div>
                    )}
                  </div>
                ))}
              </div>
            </div>
          );
        })}
      </div>

      <div className="sequence-editor-buttons">
        <button onClick={onPrev}>Back</button>
        <button onClick={handleSave}>Save and Continue</button>
      </div>
    </div>
  );
};

export default HookSequenceEditor;
