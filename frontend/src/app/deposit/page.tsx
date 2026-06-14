'use client';

import { useState } from 'react';
import { Address, useContractWrite, useAccount } from 'wagmi';
import { parseUnits } from 'viem';
import Navbar from '../../components/Navbar';
import useProtocol from '../../hooks/useProtocol';
import { abis } from '../../contracts/abis';
import addresses from '../../contracts/addresses.json';

export default function DepositPage() {
  const { supportedTokens } = useProtocol();
  const { address: userAddress } = useAccount();
  const [selectedToken, setSelectedToken] = useState(supportedTokens[0].address);
  const [amount, setAmount] = useState('0');

  const selectedTokenInfo = supportedTokens.find((token) => token.address === selectedToken);
  const decimals = selectedTokenInfo?.decimals ?? 18;

  const args = [
    supportedTokens.map((t) => t.address),
    supportedTokens.map((t) => (t.address === selectedToken ? parseUnits(amount || '0', decimals) : 0n)),
    (userAddress || '0x0000000000000000000000000000000000000000') as Address,
  ];

  const { write, isLoading, error } = useContractWrite({
    address: addresses.YieldGuardVault as Address,
    abi: abis.YieldGuardVault,
    functionName: 'depositMulti',
    args,
    // Enable only when wallet connected and a positive amount is entered
    enabled: Boolean(userAddress && Number(amount) > 0),
  });

  const isButtonDisabled = !write;

  return (
    <>
      <Navbar />
      <main className="p-10 max-w-4xl mx-auto">
        <div className="mb-8">
          <h1 className="text-4xl font-bold text-white">Depositar</h1>
          <p className="mt-2 text-slate-400">Deposita fondos en YieldGuard Vault.</p>
          {/* No demo banner needed */}
        </div>

        <div className="rounded-3xl border border-slate-800/70 bg-slate-950/80 p-8 shadow-lg shadow-slate-950/20">
          <div className="grid gap-6">
            <label className="grid gap-2 text-sm text-slate-300">
              Token
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
              Monto
              <input
                type="number"
                min="0"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                className="rounded-2xl border border-slate-800 bg-slate-900 px-4 py-3 text-white"
              />
            </label>

            <button
              type="button"
              disabled={isButtonDisabled}
              onClick={() => write?.()}
              className="inline-flex items-center justify-center rounded-2xl bg-indigo-600 px-6 py-3 text-sm font-semibold text-white transition hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-50"
            >
              {isLoading ? 'Enviando...' : 'Depositar'}
            </button>

            {error && (
              <div className="rounded-2xl border border-rose-500/40 bg-rose-500/10 p-4 text-sm text-rose-200">
                {error.message}
              </div>
            )}
          </div>
        </div>
      </main>
    </>
  );
}
