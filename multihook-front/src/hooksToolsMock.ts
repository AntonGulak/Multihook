export const mockHooks = [
  {
    id: '1',
    name: 'V4-orderbook',
    description: 'Limit order hook for Uniswap with intent-based orderbook.',
    hooks: {
      beforeInitialize: false,
      afterInitialize: true,
      beforeAddLiquidity: false,
      afterAddLiquidity: true,
      beforeRemoveLiquidity: false,
      afterRemoveLiquidity: true,
      beforeSwap: false,
      afterSwap: false,
      beforeDonate: false,
      afterDonate: false,
    }
  },
  {
    id: '2',
    name: 'FlexFee',
    description: 'Protecting LPs from impermanent loss using dynamic fees based on volatility and swap size.',
    hooks: {
      beforeInitialize: true,
      afterInitialize: false,
      beforeAddLiquidity: true,
      afterAddLiquidity: false,
      beforeRemoveLiquidity: false,
      afterRemoveLiquidity: true,
      beforeSwap: true,
      afterSwap: false,
      beforeDonate: false,
      afterDonate: false,
    }
  },
  {
    id: '3',
    name: 'UniCast',
    description: 'A forward-look event hook for LSTs and yield-bearing tokens.',
    hooks: {
      beforeInitialize: false,
      afterInitialize: false,
      beforeAddLiquidity: true,
      afterAddLiquidity: true,
      beforeRemoveLiquidity: false,
      afterRemoveLiquidity: false,
      beforeSwap: true,
      afterSwap: true,
      beforeDonate: false,
      afterDonate: true,
    }
  },
  {
    id: '4',
    name: 'Advanced Orders',
    description: 'Advanced Orders Hook to create Stop Loss, Buy Stop, Buy Limit, and Take Profit Orders.',
    hooks: {
      beforeInitialize: false,
      afterInitialize: true,
      beforeAddLiquidity: true,
      afterAddLiquidity: false,
      beforeRemoveLiquidity: true,
      afterRemoveLiquidity: false,
      beforeSwap: false,
      afterSwap: true,
      beforeDonate: false,
      afterDonate: false,
    }
  },
  {
    id: '5',
    name: 'Timelock Addition to the Points Loyalty Repo',
    description: 'Lock-down Incentivized Liquidity using a beforeRemoveLiquidity hook to ensure sufficient time has passed.',
    hooks: {
      beforeInitialize: true,
      afterInitialize: true,
      beforeAddLiquidity: false,
      afterAddLiquidity: true,
      beforeRemoveLiquidity: true,
      afterRemoveLiquidity: false,
      beforeSwap: false,
      afterSwap: false,
      beforeDonate: false,
      afterDonate: false,
    }
  },
  {
    id: '6',
    name: 'StableSwap',
    description: 'NoOp with full functionality of Curve-liked AMM.',
    hooks: {
      beforeInitialize: false,
      afterInitialize: true,
      beforeAddLiquidity: true,
      afterAddLiquidity: false,
      beforeRemoveLiquidity: false,
      afterRemoveLiquidity: true,
      beforeSwap: true,
      afterSwap: false,
      beforeDonate: false,
      afterDonate: true,
    }
  },
  {
    id: '7',
    name: 'Concentrated Incentives Hook',
    description: 'Incentivizing only the active tick to provide transparent and optimal incentives.',
    hooks: {
      beforeInitialize: true,
      afterInitialize: true,
      beforeAddLiquidity: false,
      afterAddLiquidity: false,
      beforeRemoveLiquidity: true,
      afterRemoveLiquidity: true,
      beforeSwap: false,
      afterSwap: true,
      beforeDonate: false,
      afterDonate: false,
    }
  },
  {
    id: '8',
    name: 'LBP Hook',
    description: 'Permissionless LBP sales for everyone.',
    hooks: {
      beforeInitialize: false,
      afterInitialize: false,
      beforeAddLiquidity: false,
      afterAddLiquidity: true,
      beforeRemoveLiquidity: true,
      afterRemoveLiquidity: true,
      beforeSwap: false,
      afterSwap: false,
      beforeDonate: true,
      afterDonate: false,
    }
  }
];
