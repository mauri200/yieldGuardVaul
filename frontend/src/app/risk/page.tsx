'use client';

import Navbar from '../../components/Navbar';
import useProtocol from '../../hooks/useProtocol';
import StatCard from '../../components/StatCard';

export default function RiskPage() {
  const { riskScore, stormMode } = useProtocol();

  return (
    <>
      <Navbar />
      <main className="p-10 max-w-6xl mx-auto">
        <div className="mb-8">
          <h1 className="text-4xl font-bold text-white">Riesgo y Storm Mode</h1>
          <p className="mt-2 text-slate-400">Monitorea el estado de riesgo y la protección de YieldGuard.</p>
        </div>

        <div className="grid gap-4 md:grid-cols-2">
          <StatCard
            title="Puntaje de riesgo"
            value={riskScore.isLoading ? 'Cargando...' : riskScore.data ? riskScore.data.toString() : '0'}
            description="Valor calculado por el motor de riesgo"
          />
          <StatCard
            title="Storm Mode"
            value={stormMode.isLoading ? 'Cargando...' : stormMode.data ? 'Activo' : 'Inactivo'}
            description="Modo protegido para mercados volátiles"
            isPositive={!stormMode.data}
          />
        </div>

        <section className="mt-10 rounded-3xl border border-slate-800/70 bg-slate-950/80 p-8 shadow-lg shadow-slate-950/20">
          <h2 className="text-2xl font-semibold text-white">Estrategias de YieldGuard</h2>
          <div className="mt-6 grid gap-4 sm:grid-cols-2">
            <div className="rounded-2xl border border-slate-800/80 bg-slate-900 p-5">
              <h3 className="text-lg font-semibold text-white">Lending Strategy</h3>
              <p className="mt-2 text-slate-400">Deposita USDC en un mercado de lending para generar rendimiento pasivo.</p>
            </div>
            <div className="rounded-2xl border border-slate-800/80 bg-slate-900 p-5">
              <h3 className="text-lg font-semibold text-white">Stable Yield Strategy</h3>
              <p className="mt-2 text-slate-400">Protege capital estable con USDC en estrategias de yield conservador.</p>
            </div>
            <div className="rounded-2xl border border-slate-800/80 bg-slate-900 p-5">
              <h3 className="text-lg font-semibold text-white">Collateral Yield Strategy</h3>
              <p className="mt-2 text-slate-400">Usa activos tokenizados como colateral para generar rendimiento adicional.</p>
            </div>
            <div className="rounded-2xl border border-slate-800/80 bg-slate-900 p-5">
              <h3 className="text-lg font-semibold text-white">Defensive Strategy</h3>
              <p className="mt-2 text-slate-400">Reduce la exposición en períodos de alta volatilidad para proteger capital.</p>
            </div>
          </div>
        </section>
      </main>
    </>
  );
}
