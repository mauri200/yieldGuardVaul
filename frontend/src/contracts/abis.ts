export const abis = {
  YieldGuardVault: [
    {
      type: 'function',
      name: 'asset',
      inputs: [],
      outputs: [{ name: '', type: 'address' }],
      stateMutability: 'view'
    },
    {
      type: 'function',
      name: 'totalAssets',
      inputs: [],
      outputs: [{ name: '', type: 'uint256' }],
      stateMutability: 'view'
    },
    {
      type: 'function',
      name: 'depositMulti',
      inputs: [
        { name: 'tokens', type: 'address[]' },
        { name: 'amounts', type: 'uint256[]' },
        { name: 'receiver', type: 'address' }
      ],
      outputs: [{ name: '', type: 'uint256' }],
      stateMutability: 'nonpayable'
    },
    {
      type: 'function',
      name: 'redeemMulti',
      inputs: [
        { name: 'tokens', type: 'address[]' },
        { name: 'shareAmounts', type: 'uint256[]' },
        { name: 'receiver', type: 'address' }
      ],
      outputs: [{ name: '', type: 'uint256[]' }],
      stateMutability: 'nonpayable'
    }
  ],
  PriceOracle: [
    {
      type: 'function',
      name: 'getPrice',
      inputs: [{ name: 'token', type: 'address' }],
      outputs: [{ name: '', type: 'uint256' }],
      stateMutability: 'view'
    }
  ],
  RiskEngine: [
    {
      type: 'function',
      name: 'getRiskScore',
      inputs: [],
      outputs: [{ name: '', type: 'uint256' }],
      stateMutability: 'view'
    }
  ],
  StormController: [
    {
      type: 'function',
      name: 'isStormMode',
      inputs: [],
      outputs: [{ name: '', type: 'bool' }],
      stateMutability: 'view'
    }
  ],
  AssetRegistry: [
    {
      type: 'function',
      name: 'isSupported',
      inputs: [{ name: 'token', type: 'address' }],
      outputs: [{ name: '', type: 'bool' }],
      stateMutability: 'view'
    }
  ]
};
