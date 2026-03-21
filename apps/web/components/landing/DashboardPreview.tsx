'use client';

export default function DashboardPreview() {
  const rows = [
    { name: 'Sarah Mitchell', amount: '1,250', status: 'In Conversation', statusColor: 'bg-blue-400', days: 42 },
    { name: 'James Chen', amount: '3,800', status: 'Payment Plan', statusColor: 'bg-amber-400', days: 67 },
    { name: 'Maria Rodriguez', amount: '890', status: 'Settled', statusColor: 'bg-emerald-400', days: 23 },
    { name: 'David Park', amount: '2,100', status: 'Contacted', statusColor: 'bg-violet-400', days: 15 },
    { name: 'Emma Thompson', amount: '5,400', status: 'Settled', statusColor: 'bg-emerald-400', days: 89 },
  ];

  return (
    <div className="dash-frame bg-base-100 w-full max-w-[620px]">
      {/* Title bar */}
      <div className="flex items-center gap-2 border-b border-base-300/60 bg-base-200/60 px-4 py-2.5">
        <div className="flex gap-1.5">
          <div className="h-2.5 w-2.5 rounded-full bg-error/60" />
          <div className="h-2.5 w-2.5 rounded-full bg-warning/60" />
          <div className="h-2.5 w-2.5 rounded-full bg-success/60" />
        </div>
        <div className="flex-1 text-center">
          <div className="inline-block rounded-md bg-base-300/50 px-8 py-0.5 text-[10px] text-base-content/40 font-mono">
            app.dragun.app/dashboard
          </div>
        </div>
      </div>

      {/* Dashboard content */}
      <div className="p-4 space-y-4">
        {/* Stats row */}
        <div className="grid grid-cols-4 gap-2">
          {[
            { label: 'Active', value: '24', trend: null },
            { label: 'Recovered', value: '$18.4k', trend: '+12%' },
            { label: 'Rate', value: '82%', trend: '+4%' },
            { label: 'Avg Time', value: '3.2d', trend: '-18%' },
          ].map((s) => (
            <div key={s.label} className="rounded-lg border border-base-300/60 bg-base-200/30 p-2.5">
              <p className="text-[9px] font-semibold uppercase tracking-wider text-base-content/40">{s.label}</p>
              <p className="text-lg font-bold tracking-tight leading-tight">{s.value}</p>
              {s.trend && (
                <p className={`text-[10px] font-semibold ${s.trend.startsWith('+') ? 'text-success' : 'text-primary'}`}>{s.trend}</p>
              )}
            </div>
          ))}
        </div>

        {/* Table */}
        <div className="rounded-lg border border-base-300/60 overflow-hidden">
          <div className="grid grid-cols-[1fr_80px_100px_50px] gap-2 bg-base-200/40 px-3 py-2 text-[9px] font-semibold uppercase tracking-wider text-base-content/40">
            <span>Debtor</span>
            <span>Amount</span>
            <span>Status</span>
            <span>Days</span>
          </div>
          {rows.map((row, i) => (
            <div
              key={row.name}
              className={`grid grid-cols-[1fr_80px_100px_50px] gap-2 items-center px-3 py-2 text-[11px] ${i < rows.length - 1 ? 'border-b border-base-300/40' : ''}`}
            >
              <span className="font-medium truncate">{row.name}</span>
              <span className="font-mono text-base-content/70">${row.amount}</span>
              <span className="flex items-center gap-1.5">
                <span className={`h-1.5 w-1.5 rounded-full ${row.statusColor}`} />
                <span className="text-base-content/60 text-[10px]">{row.status}</span>
              </span>
              <span className="text-base-content/40 font-mono text-[10px]">{row.days}d</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
