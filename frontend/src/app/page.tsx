"use client";

import Link from 'next/link';
import Navbar from '../components/Navbar';

export default function HomePage() {
  return (
    <>
      <Navbar />

      <main className="p-10 max-w-6xl mx-auto">
        <section className="rounded-3xl border border-slate-800/70 bg-slate-950/80 p-10 shadow-xl shadow-slate-950/20">
          <h1 className="text-5xl font-bold text-white">YieldGuard</h1>
          <p className="mt-4 max-w-2xl text-lg text-slate-400">
            YieldGuard gestiona tus tokens de acciones (USDC, AMZN, TSLA, PLTR, NFLX, AMD) mediante estrategias de rendimiento y control de riesgo. Deposita, gana rendimiento y protege tu capital.
          </p>

          <div className="mt-10 grid gap-4 sm:grid-cols-2">
            <Link href="/dashboard" className="block rounded-2xl border border-slate-800/90 bg-slate-900 px-6 py-6 text-left transition hover:-translate-y-0.5 hover:border-slate-700">
              <h2 className="text-xl font-semibold text-white">Dashboard</h2>
              <p className="mt-2 text-slate-400">Ver valor total del vault, riesgo y estado de storm mode.</p>
            </Link>

            <Link href="/deposit" className="block rounded-2xl border border-slate-800/90 bg-slate-900 px-6 py-6 text-left transition hover:-translate-y-0.5 hover:border-slate-700">
              <h2 className="text-xl font-semibold text-white">Depositar</h2>
              <p className="mt-2 text-slate-400">Depositar activos soportados como USDC, AMZN, TSLA, PLTR, NFLX y AMD.</p>
            </Link>

            <Link href="/withdraw" className="block rounded-2xl border border-slate-800/90 bg-slate-900 px-6 py-6 text-left transition hover:-translate-y-0.5 hover:border-slate-700">
              <h2 className="text-xl font-semibold text-white">Retirar</h2>
              <p className="mt-2 text-slate-400">Retirar fondos de YieldGuard Vault en el activo elegido.</p>
            </Link>
          </div>
        </section>
      </main>
    </>
  );
}
