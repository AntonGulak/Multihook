import React, { useState, useCallback } from 'react';
import '../../../styles/hookManagement/createMultiHook.css';
import HookList from './HookList';
import { HookCardProps } from './hookCard';
import HookSequenceEditor from './HookSequenceEditor';

interface HookData {
  network: string;
  hookName: string;
  hookLogo: string;
  description: string;
}

const CreateMultiHook: React.FC = () => {
  const [step, setStep] = useState(1);
  const [hookData, setHookData] = useState<HookData>({
    network: '',
    hookName: '',
    hookLogo: '',
    description: ''
  });
  const [selectedHooks, setSelectedHooks] = useState<HookCardProps['hook'][]>([]);
  const [orderedHooks, setOrderedHooks] = useState<HookCardProps['hook'][]>([]);

  const handleNextStep = useCallback((e: React.FormEvent) => {
    e.preventDefault();
    if (!hookData.network || !hookData.hookName || !hookData.hookLogo || !hookData.description) {
      alert("Please fill in all fields");
      return;
    }
    setStep(2);
  }, [hookData]);

  const handlePrevStep = useCallback(() => {
    setStep(prevStep => prevStep - 1);
  }, []);

  const handleNextStepFromHooks = useCallback(() => {
    if (selectedHooks.length === 0) {
      alert("Please select at least one hook.");
      return;
    }
    setStep(3);
  }, [selectedHooks]);

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) => {
    const { id, value } = e.target;
    setHookData((prevData) => ({
      ...prevData,
      [id]: value
    }));
  };

  const handleSelectHooks = useCallback((hooks: HookCardProps['hook'][]) => {
    setSelectedHooks(hooks);
  }, []);

  const handleSaveOrderedHooks = useCallback((orderedHooks: HookCardProps['hook'][]) => {
    setOrderedHooks(orderedHooks);
    setStep(4); 
  }, []);

  if (step === 2) {
    return (
      <HookList
        onSelectHooks={handleSelectHooks}
        onPrev={handlePrevStep}
        onNext={handleNextStepFromHooks}
      />
    );
  }

  if (step === 3) {
    return (
      <HookSequenceEditor
        selectedHooks={selectedHooks}
        onPrev={handlePrevStep}
        onSave={handleSaveOrderedHooks}
      />
    );
  }

  if (step === 4) {
    return (
      <div className="hook-summary">
        <h2>Review and Submit</h2>
        {/* Display hookData and orderedHooks for final confirmation */}
        <button onClick={handlePrevStep}>Back</button>
        <button onClick={() => alert('Hooks submitted!')}>Submit</button>
      </div>
    );
  }

  return (
    <div className="hook-form">
      <form onSubmit={handleNextStep}>
        <div className="form-group">
          <label htmlFor="network">Select Network</label>
          <select id="network" value={hookData.network} onChange={handleInputChange}>
            <option value="" disabled>Select Network</option>
            <option value="Ethereum">Ethereum</option>
            <option value="Arbitrum">Arbitrum</option>
            <option value="Binance Smart Chain">Binance Smart Chain</option>
          </select>
        </div>
        <div className="form-group">
          <label htmlFor="hookName">Hook name</label>
          <input
            id="hookName"
            type="text"
            value={hookData.hookName}
            onChange={handleInputChange}
            placeholder="Enter Hook Name"
          />
        </div>
        <div className="form-group">
          <label htmlFor="hookLogo">Hook logo</label>
          <input
            id="hookLogo"
            type="text"
            value={hookData.hookLogo}
            onChange={handleInputChange}
            placeholder="Paste URL here"
          />
        </div>
        <div className="form-group">
          <label htmlFor="description">Short Project Description</label>
          <textarea
            id="description"
            value={hookData.description}
            onChange={handleInputChange}
            placeholder="Max 300 symbols"
            maxLength={300}
          />
        </div>
        <button type="submit" className="submit-btn">Next</button>
      </form>
    </div>
  );
};

export default CreateMultiHook;
