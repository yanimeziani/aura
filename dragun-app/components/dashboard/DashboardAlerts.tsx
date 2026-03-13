'use client';

import { ReactNode } from 'react';
import { useTranslations } from 'next-intl';

/** Renders at most 2 alerts to reduce cognitive load (Laws of UX: Hick's Law, Progressive disclosure). */
interface Props {
  children: ReactNode[];
}

export default function DashboardAlerts({ children }: Props) {
  const t = useTranslations('Dashboard');
  const alerts = Array.isArray(children) ? children.filter(Boolean) : [];
  const visible = alerts.slice(0, 2);

  if (visible.length === 0) return null;

  return (
    <section aria-label={t('updatesAndAlerts')} className="space-y-3">
      {visible.map((alert, i) => (
        <div key={i}>{alert}</div>
      ))}
    </section>
  );
}
