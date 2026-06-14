'use client';

import Navbar from '../../components/Navbar';
import useProtocol from '../../hooks/useProtocol';
import StatCard from '../../components/StatCard';
import addresses from '../../contracts/addresses.json';

export default function DashboardPage() {
  const { vaultTotalAssets, riskScore, stormMode, supportedTokens, userAddress } = useProtocol();

  return (
    <>
      <Navbar />
      <main className="p-10 max-w-6xl mx-auto">
        <div className="mb-8 flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <h1 className="text-4xl font-bold text-white">Dashboard YieldGuard</h1>
            <p className="mt-2 text-slate-400">Resumen del vault, riesgo y activos soportados.</p>
          </div>
          <div className="rounded-3xl border border-slate-800/70 bg-slate-900/80 px-4 py-3 text-sm text-slate-300">
            <p className="font-medium text-slate-100">Wallet conectada</p>
            <p className="break-all">{userAddress ?? 'No conectado'}</p>
          </div>
        </div>

        <div className="grid gap-4 md:grid-cols-3">
          <StatCard
            title="Valor total del vault"
            value={vaultTotalAssets.isLoading ? 'Cargando...' : vaultTotalAssets.data ? `${Number(vaultTotalAssets.data.toString()) / 1e6} USDC` : '0'}
            description="Valor total gestionado en el protocolo"
          />
          <StatCard
            title="Puntaje de riesgo"
            value={riskScore.isLoading ? 'Cargando...' : riskScore.data ? riskScore.data.toString() : '0'}
            description="Evaluación del motor de riesgo"
          />
          <StatCard
            title="Storm Mode"
            value={stormMode.isLoading ? 'Cargando...' : stormMode.data ? 'Activo' : 'Inactivo'}
            description="Estado de modo tormenta"
            isPositive={!stormMode.data}
          />
        </div>

        <section className="mt-10 rounded-3xl border border-slate-800/70 bg-slate-950/80 p-6">
          <div className="mb-4 flex items-center justify-between">
            <h2 className="text-2xl font-semibold text-white">Activos soportados</h2>
            <span className="text-sm text-slate-500">{supportedTokens.length} tokens</span>
          </div>
          <div className="grid gap-3 sm:grid-cols-2">
            {supportedTokens.map((token) => (
              <div key={token.symbol} className="rounded-2xl border border-slate-800/80 bg-slate-900 p-4">
                <p className="text-sm font-medium text-slate-400">{token.symbol}</p>
                <p className="mt-2 text-sm text-slate-300 break-all">{token.address}</p>
              </div>
            ))}
          </div>
        </section>

        <section className="mt-10 rounded-3xl border border-slate-800/70 bg-slate-950/80 p-6">
          <h2 className="text-2xl font-semibold text-white">Contratos principales</h2>
          <div className="mt-4 grid gap-3 md:grid-cols-2">
            {[
              { label: 'YieldGuard Vault', address: addresses.YieldGuardVault },
              { label: 'Strategy Router', address: addresses.StrategyRouter },
              { label: 'Reserve Vault', address: addresses.ReserveVault },
              { label: 'Asset Registry', address: addresses.AssetRegistry },
              { label: 'Price Oracle', address: addresses.PriceOracle }
            ].map((item) => (
              <div key={item.label} className="rounded-2xl border border-slate-800/80 bg-slate-900 p-4">
                <p className="text-sm font-medium text-slate-400">{item.label}</p>
                <p className="mt-2 text-sm text-slate-300 break-all">{item.address}</p>
              </div>
            ))}
          </div>
        </section>
      </main>
    </>
  );
}
