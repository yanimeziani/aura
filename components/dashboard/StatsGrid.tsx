import type { LucideIcon } from 'lucide-react';

export interface StatItem {
  label: string;
  value: string;
  icon: LucideIcon;
  trend: string;
  sub: string;
}

export default function StatsGrid({ stats }: { stats: StatItem[] }) {
  return (
    <div className="grid grid-cols-2 gap-3 lg:grid-cols-5">
      {stats.map((stat) => (
        <div
          key={stat.label}
          className="card bg-base-200/50 border border-base-300/50 shadow-warm"
        >
          <div className="card-body p-4 sm:p-5">
            <div className="flex items-start justify-between">
              <p className="text-label">{stat.label}</p>
              <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-base-300/50 text-base-content/40">
                <stat.icon className="h-4 w-4" />
              </div>
            </div>
            <p className="mt-1 text-2xl font-bold tracking-tight">{stat.value}</p>
            <div className="mt-2 flex items-center gap-2">
              <span className="badge badge-ghost badge-sm text-[10px] font-semibold">
                {stat.trend}
              </span>
              <span className="text-[10px] font-medium text-base-content/40 uppercase tracking-wider">
                {stat.sub}
              </span>
            </div>
          </div>
        </div>
      ))}
    </div>
  );
}
