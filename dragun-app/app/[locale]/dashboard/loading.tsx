export default function DashboardLoading() {
  return (
    <div className="min-h-screen bg-base-100 pb-24 md:pb-8">
      <nav className="sticky top-0 z-30 border-b border-base-300/50 bg-base-100/90 backdrop-blur-xl">
        <div className="app-shell flex h-16 items-center justify-between">
          <div className="h-8 w-28 rounded-lg bg-base-300/50 animate-pulse" />
          <div className="h-10 w-32 rounded-xl bg-base-300/50 animate-pulse" />
        </div>
      </nav>

      <main className="app-shell space-y-6 py-6">
        <div className="space-y-2">
          <div className="h-8 w-56 rounded-lg bg-base-300/50 animate-pulse" />
          <div className="h-4 w-80 rounded bg-base-300/30 animate-pulse" />
        </div>

        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-5">
          {Array.from({ length: 5 }).map((_, i) => (
            <div key={i} className="card bg-base-200/50 border border-base-300/50">
              <div className="card-body p-4 space-y-2">
                <div className="h-3 w-16 rounded bg-base-300/40 animate-pulse" />
                <div className="h-7 w-24 rounded bg-base-300/50 animate-pulse" />
                <div className="h-3 w-12 rounded bg-base-300/30 animate-pulse" />
              </div>
            </div>
          ))}
        </div>

        <div className="grid grid-cols-1 gap-6 lg:grid-cols-12">
          <div className="lg:col-span-8">
            <div className="card bg-base-200/50 border border-base-300/50 min-h-[400px]">
              <div className="border-b border-base-300/50 p-4">
                <div className="h-5 w-40 rounded bg-base-300/50 animate-pulse" />
              </div>
              <div className="p-4 space-y-4">
                {Array.from({ length: 4 }).map((_, i) => (
                  <div key={i} className="flex items-center gap-4">
                    <div className="h-10 w-10 rounded-lg bg-base-300/40 animate-pulse shrink-0" />
                    <div className="flex-1 space-y-2">
                      <div className="h-4 w-32 rounded bg-base-300/40 animate-pulse" />
                      <div className="h-3 w-48 rounded bg-base-300/30 animate-pulse" />
                    </div>
                    <div className="h-6 w-20 rounded-full bg-base-300/30 animate-pulse" />
                  </div>
                ))}
              </div>
            </div>
          </div>
          <aside className="space-y-6 lg:col-span-4">
            {Array.from({ length: 2 }).map((_, i) => (
              <div key={i} className="card bg-base-200/50 border border-base-300/50 min-h-[200px]">
                <div className="card-body p-5">
                  <div className="h-5 w-32 rounded bg-base-300/50 animate-pulse mb-4" />
                  <div className="space-y-3">
                    <div className="h-3 w-full rounded bg-base-300/30 animate-pulse" />
                    <div className="h-3 w-3/4 rounded bg-base-300/30 animate-pulse" />
                  </div>
                </div>
              </div>
            ))}
          </aside>
        </div>
      </main>
    </div>
  );
}
