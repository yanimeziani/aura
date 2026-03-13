export default function MarketingLoading() {
  return (
    <main className="animate-pulse">
      <section className="py-16 sm:py-20">
        <div className="app-shell max-w-3xl space-y-5">
          <div className="h-5 w-36 rounded-full bg-base-300/40" />
          <div className="h-12 w-3/4 rounded-lg bg-base-300/50" />
          <div className="h-5 w-2/3 rounded bg-base-300/30" />
        </div>
      </section>
      <section className="py-16">
        <div className="app-shell grid gap-5 md:grid-cols-3">
          {Array.from({ length: 3 }).map((_, i) => (
            <div key={i} className="card bg-base-200/50 border border-base-300/50 min-h-[260px]">
              <div className="card-body p-6 space-y-3">
                <div className="h-10 w-10 rounded-xl bg-base-300/40" />
                <div className="h-5 w-32 rounded bg-base-300/50" />
                <div className="space-y-2">
                  <div className="h-3 w-full rounded bg-base-300/30" />
                  <div className="h-3 w-5/6 rounded bg-base-300/30" />
                </div>
              </div>
            </div>
          ))}
        </div>
      </section>
    </main>
  );
}
