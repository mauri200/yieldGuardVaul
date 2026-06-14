'use client';

import { useState } from 'react';
import { Address, useContractWrite } from 'wagmi';
import { parseUnits } from 'viem';
import Navbar from '../../components/Navbar';
import useProtocol from '../../hooks/useProtocol';
import { abis } from '../../contracts/abis';
import addresses from '../../contracts/addresses.json';

export default function WithdrawPage() {
  const { supportedTokens, userAddress } = useProtocol();
  const [selectedToken, setSelectedToken] = useState(supportedTokens[0].address);
  const [shares, setShares] = useState('0');

  const selectedTokenInfo = supportedTokens.find((token) => token.address === selectedToken);
  const tokenSymbol = selectedTokenInfo?.symbol ?? 'USDC';
  const decimals = selectedTokenInfo?.decimals ?? 18;

  const args = [
    supportedTokens.map((t) => t.address),
    supportedTokens.map((t) => (t.address === selectedToken ? parseUnits(shares || '0', decimals) : 0n)),
    (userAddress || '0x0000000000000000000000000000000000000000') as Address,
  ];

  const contractWrite = useContractWrite({
    address: addresses.YieldGuardVault as Address,
    abi: abis.YieldGuardVault,
    functionName: 'redeemMulti',
    args,
    enabled: Boolean(userAddress && shares && shares !== '0'),
  });

  const isButtonDisabled = !contractWrite.write;

  return (
    <>
      <Navbar />
      <main className="p-10 max-w-4xl mx-auto">
        <div className="mb-8">
          <h1 className="text-4xl font-bold text-white">Retirar</h1>
          <p className="mt-2 text-slate-400">Retira tus activos del vault YieldGuard.</p>
        </div>

        <div className="rounded-3xl border border-slate-800/70 bg-slate-950/80 p-8 shadow-lg shadow-slate-950/20">
          <div className="grid gap-6">
            <label className="grid gap-2 text-sm text-slate-300">
              Token de salida
              <select
                value={selectedToken}
                onChange={(event) => setSelectedToken(event.target.value)}
                className="rounded-2xl border border-slate-800 bg-slate-900 px-4 py-3 text-white"
              >
                {supportedTokens.map((token) => (
                  <option key={token.address} value={token.address}>{token.symbol}</option>
                ))}
              </select>
            </label>

            <label className="grid gap-2 text-sm text-slate-300">
              Shares a retirar
              <input
                type="number"
                min="0"
                step="0.0001"
                value={shares}
                onChange={(event) => setShares(event.target.value)}
                className="rounded-2xl border border-slate-800 bg-slate-900 px-4 py-3 text-white"
              />
            </label>

            <button
              type="button"
              disabled={isButtonDisabled}
              onClick={() => contractWrite.write?.()}
              className="inline-flex items-center justify-center rounded-2xl bg-indigo-600 px-6 py-3 text-sm font-semibold text-white transition hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-50"
            >
              {contractWrite.isLoading ? 'Enviando...' : 'Retirar'}
            </button>

            {contractWrite.error && (
              <div className="rounded-2xl border border-rose-500/40 bg-rose-500/10 p-4 text-sm text-rose-200">
                {contractWrite.error.message}
              </div>
            )}
          </div>
        </main>
      </>
    );
  }
  );
