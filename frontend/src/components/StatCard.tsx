import React from 'react';

interface StatCardProps {
  title: string;
  value: string | number;
  change?: string;
  isPositive?: boolean;
  description?: string;
  icon?: React.ReactNode;
  loading?: boolean;
}

export default function StatCard({
  title,
  value,
  change,
  isPositive = true,
  description,
  icon,
  loading = false
}: StatCardProps) {
  return (
    <div className="card p-6 transition-all duration-300 hover:border-slate-700/50 hover:shadow-lg hover:-translate-y-0.5">
      <div className="flex items-center justify-between">
        <span className="text-sm font-medium text-slate-400">{title}</span>
        {icon && (
          <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-slate-800 text-slate-300 border border-slate-700/50">
            {icon}
          </div>
        )}
      </div>

      <div className="mt-4 flex items-baseline gap-2">
        {loading ? (
          <div className="h-9 w-28 animate-pulse rounded-lg bg-slate-800" />
        ) : (
          <span className="text-3xl font-bold tracking-tight text-white">{value}</span>
        )}

        {change && !loading && (
          <span
            className={`inline-flex items-center rounded-md px-2 py-0.5 text-xs font-semibold ${
              isPositive ? 'bg-emerald-500/10 text-emerald-400' : 'bg-rose-500/10 text-rose-400'
            }`}
          >
            {change}
          </span>
        )}
      </div>

      {description && !loading && (
        <p className="mt-2 text-xs text-slate-500">{description}</p>
      )}
    </div>
  );
}
