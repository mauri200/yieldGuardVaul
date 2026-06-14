'use client';

import { useMemo } from 'react';
import { Address, useAccount, useContractRead } from 'wagmi';
import { abis } from '../contracts/abis';
import addresses from '../contracts/addresses.json';

const supportedTokens = [
  { symbol: 'USDC', address: addresses.USDC, decimals: 6 },
  { symbol: 'AMZN', address: addresses.AMZN, decimals: 18 },
  { symbol: 'TSLA', address: addresses.TSLA, decimals: 18 },
  { symbol: 'PLTR', address: addresses.PLTR, decimals: 18 },
  { symbol: 'NFLX', address: addresses.NFLX, decimals: 18 },
  { symbol: 'AMD', address: addresses.AMD, decimals: 18 }
];

export default function useProtocol() {
  const { address: userAddress } = useAccount();

  const vaultTotalAssets = useContractRead({
    address: addresses.YieldGuardVault as Address,
    abi: abis.YieldGuardVault,
    functionName: 'totalAssets'
  });

  const riskScore = useContractRead({
    address: addresses.RiskEngine as Address,
    abi: abis.RiskEngine,
    functionName: 'getRiskScore'
  });

  const stormMode = useContractRead({
    address: addresses.StormController as Address,
    abi: abis.StormController,
    functionName: 'isStormMode'
  });

  return {
    supportedTokens,
    userAddress,
    vaultTotalAssets,
    riskScore,
    stormMode
  };
}
