import { getSovereignData } from '@/app/actions/sovereign-data';
import { Shield, Zap, Calendar, User, Terminal, ArrowRight, Activity } from 'lucide-react';

export default async function SovereignDashboard() {
  const data = await getSovereignData();

  if (!data.success) {
    return (
      <div className="min-h-screen bg-black text-red-500 font-mono p-8 flex items-center justify-center border-4 border-red-500">
        ERROR_SYSTEM_FAILURE: {data.error}
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-black text-white font-mono p-4 md:p-8 space-y-8 selection:bg-white selection:text-black">
      {/* HEADER */}
      <header className="border-4 border-white p-6 flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
        <div>
          <h1 className="text-4xl font-black tracking-tighter uppercase leading-none">Sovereign OS</h1>
          <p className="text-sm opacity-70 mt-2">v1.0.0-PROTOTYPE // COMMAND_CENTER</p>
        </div>
        <div className="flex items-center gap-6">
          <div className="flex flex-col items-end">
            <span className="text-xs uppercase opacity-50">Local Time</span>
            <span>{new Date().toLocaleTimeString()}</span>
          </div>
          <div className="flex flex-col items-end text-green-400">
            <span className="text-xs uppercase opacity-50">System Status</span>
            <span className="flex items-center gap-2">
              <Activity className="w-4 h-4 animate-pulse" />
              ONLINE
            </span>
          </div>
        </div>
      </header>

      {/* GRID LAYOUT */}
      <div className="grid grid-cols-1 md:grid-cols-12 gap-8">
        
        {/* LEFT COLUMN: RECOVERY OPS */}
        <section className="md:col-span-8 space-y-8">
          <div className="border-4 border-white p-0">
            <div className="bg-white text-black p-2 flex justify-between items-center px-4">
              <h2 className="font-bold uppercase tracking-widest flex items-center gap-2">
                <Shield className="w-4 h-4" /> Venice Gym Pilot
              </h2>
              <span className="text-xs">CLIENT: MOUNIR</span>
            </div>
            <div className="p-6">
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-6 mb-8 text-center sm:text-left">
                <div className="border-2 border-white p-4">
                  <span className="text-xs uppercase opacity-50 block mb-1 underline">Outstanding</span>
                  <span className="text-3xl font-black">${data.recoveryStats?.outstanding?.toFixed(2)}</span>
                </div>
                <div className="border-2 border-white p-4 bg-white/5">
                  <span className="text-xs uppercase opacity-50 block mb-1 underline">Accounts</span>
                  <span className="text-3xl font-black">{data.recoveryStats?.count}</span>
                </div>
                <div className="border-2 border-white p-4">
                  <span className="text-xs uppercase opacity-50 block mb-1 underline">Recovered</span>
                  <span className="text-3xl font-black text-green-400">{data.recoveryStats?.recovered}</span>
                </div>
              </div>

              <div className="border-2 border-white">
                <table className="w-full text-left">
                  <thead className="bg-white text-black text-xs uppercase">
                    <tr>
                      <th className="p-3">Debtor</th>
                      <th className="p-3">Debt</th>
                      <th className="p-3">Status</th>
                      <th className="p-3">Action</th>
                    </tr>
                  </thead>
                  <tbody>
                    {data.topDebtors?.map((d: any) => (
                      <tr key={d.id} className="border-t-2 border-white/20 hover:bg-white/5 transition-colors">
                        <td className="p-3 font-bold">{d.name}</td>
                        <td className="p-3">${d.total_debt}</td>
                        <td className="p-3">
                          <span className={`text-[10px] px-2 py-0.5 border border-current uppercase ${
                            d.status === 'paid' ? 'text-green-400' : 'text-yellow-400'
                          }`}>
                            {d.status}
                          </span>
                        </td>
                        <td className="p-3">
                          <button className="text-xs underline hover:no-underline flex items-center gap-1 group">
                            OPEN <ArrowRight className="w-3 h-3 group-hover:translate-x-1 transition-transform" />
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          </div>

          <div className="border-4 border-white p-0">
            <div className="bg-white text-black p-2 px-4 flex justify-between items-center">
              <h2 className="font-bold uppercase tracking-widest flex items-center gap-2">
                <Terminal className="w-4 h-4" /> Agent Terminal
              </h2>
              <div className="flex gap-2">
                <span className="w-2 h-2 rounded-full bg-red-500"></span>
                <span className="w-2 h-2 rounded-full bg-yellow-500"></span>
                <span className="w-2 h-2 rounded-full bg-green-500"></span>
              </div>
            </div>
            <div className="p-6 bg-black h-64 overflow-y-auto text-sm text-green-500 leading-relaxed font-mono">
              <p className="opacity-50">[04:30:12] INITIALIZING CERBERUS RUNTIME...</p>
              <p className="opacity-50">[04:30:13] LOADING CONFIG: ~/.cerberus/config.json</p>
              <p className="opacity-50">[04:30:14] MCP SERVER STARTED: sovereign-calendar</p>
              <p className="opacity-50">[04:30:15] AGENT REGISTERED: career-twin</p>
              <p className="opacity-50">[04:30:16] AGENT REGISTERED: sdr-agent</p>
              <p className="mt-4"><span className="text-white">career-twin {">"}</span> Paved terrain for Mounir's onboarding.</p>
              <p><span className="text-white">career-twin {">"}</span> Created Sovereign Calendar event: "Onboarding Mounir".</p>
              <p className="mt-4 text-white animate-pulse">_</p>
            </div>
          </div>
        </section>

        {/* RIGHT COLUMN: TOOLS & STATUS */}
        <aside className="md:col-span-4 space-y-8">
          {/* QUICK ACTIONS */}
          <div className="border-4 border-white p-6 space-y-4">
            <h2 className="font-black text-xl uppercase tracking-tighter italic">Quick Actions</h2>
            <button className="w-full border-2 border-white p-3 hover:bg-white hover:text-black transition-all font-bold uppercase text-sm flex items-center justify-between group">
              Book Onboarding Sync <Zap className="w-4 h-4 group-hover:scale-125 transition-transform" />
            </button>
            <button className="w-full border-2 border-white p-3 hover:bg-white hover:text-black transition-all font-bold uppercase text-sm flex items-center justify-between group">
              Launch Blitzkrieg <Zap className="w-4 h-4 group-hover:scale-125 text-yellow-400 transition-transform" />
            </button>
            <p className="text-[9px] opacity-50 uppercase text-center mt-1 italic">Targeting: sdr_blitzkrieg_targets.csv</p>
            <button className="w-full border-2 border-white p-3 hover:bg-white hover:text-black transition-all font-bold uppercase text-sm flex items-center justify-between group">
              Export ICS Calendar <Calendar className="w-4 h-4" />
            </button>
          </div>

          {/* CALENDAR WIDGET */}
          <div className="border-4 border-white p-0">
            <div className="bg-white text-black p-2 px-4 font-bold uppercase text-xs flex items-center gap-2 underline decoration-2 offset-2">
              <Calendar className="w-3 h-3" /> Sovereign Calendar
            </div>
            <div className="p-6 space-y-4">
              {data.calendarStatus?.upcomingEvents?.map((ev: any) => (
                <div key={ev.id} className="border-l-4 border-white pl-4 py-1">
                  <p className="text-sm font-black uppercase">{ev.title}</p>
                  <p className="text-[10px] opacity-50">{new Date(ev.start).toLocaleString()}</p>
                  <p className="text-[10px] italic mt-1">{ev.description}</p>
                </div>
              ))}
              <div className="text-[10px] opacity-30 mt-4 text-center border-t-2 border-white/10 pt-4 uppercase">
                End-to-End Encrypted // Local Storage Only
              </div>
            </div>
          </div>

          {/* AGENT CORE */}
          <div className="border-4 border-white p-6 space-y-6">
            <h2 className="font-black text-xl uppercase tracking-tighter underline decoration-4">Agent Core</h2>
            
            <div className="space-y-4">
              <div className="flex items-start gap-4">
                <div className="p-2 border-2 border-white">
                  <User className="w-5 h-5" />
                </div>
                <div className="flex-1">
                  <div className="flex justify-between items-center mb-1">
                    <span className="text-xs font-black uppercase">Career Twin</span>
                    <span className="text-[10px] bg-green-400 text-black px-1 font-bold">READY</span>
                  </div>
                  <p className="text-[10px] opacity-70 leading-tight">Last: {data.agentStatus?.careerTwin?.lastAction}</p>
                </div>
              </div>

              <div className="flex items-start gap-4">
                <div className="p-2 border-2 border-white opacity-50">
                  <Zap className="w-5 h-5" />
                </div>
                <div className="flex-1 opacity-50">
                  <div className="flex justify-between items-center mb-1">
                    <span className="text-xs font-black uppercase">SDR Agent</span>
                    <span className="text-[10px] bg-yellow-400 text-black px-1 font-bold">IDLE</span>
                  </div>
                  <p className="text-[10px] opacity-70 leading-tight">Waiting for target list ingestion.</p>
                </div>
              </div>
            </div>
          </div>
        </aside>
      </div>

      {/* FOOTER BAR */}
      <footer className="border-4 border-white bg-white text-black p-2 px-6 flex justify-between items-center text-[10px] font-bold uppercase tracking-widest">
        <div className="flex gap-6">
          <span>CERBERUS_GATEWAY: 127.0.0.1:3000</span>
          <span>AUTONOMY_LEVEL: FULL</span>
        </div>
        <div className="hidden md:block">
          ENCRYPTION: XOR_32BIT_VAULT // SOVEREIGN_MODE: ACTIVE
        </div>
      </footer>
    </div>
  );
}
