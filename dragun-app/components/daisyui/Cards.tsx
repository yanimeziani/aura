import { ReactNode } from 'react';

interface FeatureCardProps {
  icon: ReactNode;
  title: string;
  description: string;
  variant?: 'default' | 'compact' | 'outlined';
  badge?: string;
}

export function FeatureCard({ icon, title, description, variant = 'default', badge }: FeatureCardProps) {
  const baseClasses = 'card transition-all duration-300 hover:shadow-lg hover:-translate-y-1';

  if (variant === 'compact') {
    return (
      <div className={`${baseClasses} card-side bg-base-100 border border-base-200`}>
        <div className="card-body p-6 gap-0">
          <div className="flex items-start gap-4">
            <div className="rounded-full bg-primary/10 p-3 text-primary">{icon}</div>
            <div className="flex-1">
              {badge && <span className="badge badge-sm badge-primary badge-outline mb-2">{badge}</span>}
              <h3 className="card-title text-lg">{title}</h3>
              <p className="text-sm text-base-content/70 mt-1">{description}</p>
            </div>
          </div>
        </div>
      </div>
    );
  }

  if (variant === 'outlined') {
    return (
      <div className={`${baseClasses} bg-base-100 border-2 border-primary/20 hover:border-primary/40`}>
        <div className="card-body items-center text-center p-8">
          <div className="rounded-full bg-primary/10 p-4 mb-4 text-primary">{icon}</div>
          {badge && <span className="badge badge-sm badge-primary badge-outline mb-2">{badge}</span>}
          <h3 className="card-title">{title}</h3>
          <p className="text-base-content/70 mt-2">{description}</p>
        </div>
      </div>
    );
  }

  return (
    <div className={`${baseClasses} bg-base-100 shadow-md`}>
      <div className="card-body">
        <div className="rounded-lg bg-primary/10 w-16 h-16 flex items-center justify-center mb-4 text-primary">
          {icon}
        </div>
        {badge && <span className="badge badge-sm badge-primary badge-outline mb-2">{badge}</span>}
        <h3 className="card-title text-xl">{title}</h3>
        <p className="text-base-content/70">{description}</p>
      </div>
    </div>
  );
}

interface StatCardProps {
  label: string;
  value: string | number;
  change?: string;
  trend?: 'up' | 'down' | 'neutral';
  icon?: ReactNode;
  variant?: 'default' | 'compact' | 'large';
}

export function StatCard({ label, value, change, trend = 'neutral', icon, variant = 'default' }: StatCardProps) {
  const trendColors = {
    up: 'text-success',
    down: 'text-error',
    neutral: 'text-base-content/60',
  };

  const trendIcons = {
    up: <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6" /></svg>,
    down: <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 17h8m0 0V9m0 8l-8-8-4 4-6-6" /></svg>,
    neutral: null,
  };

  if (variant === 'compact') {
    return (
      <div className="stats shadow">
        <div className="stat">
          {icon && <div className="stat-figure text-primary">{icon}</div>}
          <div className="stat-title">{label}</div>
          <div className="stat-value text-2xl">{value}</div>
          {change && (
            <div className={`stat-desc text-sm ${trendColors[trend]} flex items-center gap-1`}>
              {trendIcons[trend]}
              {change}
            </div>
          )}
        </div>
      </div>
    );
  }

  if (variant === 'large') {
    return (
      <div className="stats shadow-lg bg-gradient-to-br from-base-100 to-base-200">
        <div className="stat p-8">
          {icon && <div className="stat-figure text-primary/80">{icon}</div>}
          <div className="stat-title text-base-content/70">{label}</div>
          <div className="stat-value text-primary text-5xl">{value}</div>
          {change && (
            <div className={`stat-desc text-lg ${trendColors[trend]} flex items-center gap-1`}>
              {trendIcons[trend]}
              {change}
            </div>
          )}
        </div>
      </div>
    );
  }

  return (
    <div className="stats shadow bg-base-100">
      <div className="stat">
        {icon && <div className="stat-figure text-primary">{icon}</div>}
        <div className="stat-title">{label}</div>
        <div className="stat-value text-3xl">{value}</div>
        {change && (
          <div className={`stat-desc ${trendColors[trend]} flex items-center gap-1`}>
            {trendIcons[trend]}
            {change}
          </div>
        )}
      </div>
    </div>
  );
}

interface ActionCardProps {
  title: string;
  description?: string;
  icon?: ReactNode;
  onClick?: () => void;
  href?: string;
  variant?: 'default' | 'warning' | 'danger' | 'success';
  disabled?: boolean;
}

export function ActionCard({ title, description, icon, onClick, href, variant = 'default', disabled = false }: ActionCardProps) {
  const variantStyles = {
    default: 'bg-base-100 hover:bg-base-200 border-base-200',
    warning: 'bg-warning/10 hover:bg-warning/20 border-warning/30 text-warning-content',
    danger: 'bg-error/10 hover:bg-error/20 border-error/30 text-error-content',
    success: 'bg-success/10 hover:bg-success/20 border-success/30 text-success-content',
  };

  const content = (
    <>
      <div className="card-body p-6 gap-2">
        <div className="flex items-center gap-3">
          {icon && <div className="text-primary/80">{icon}</div>}
          <h3 className="card-title text-lg">{title}</h3>
        </div>
        {description && <p className="text-sm text-base-content/70">{description}</p>}
      </div>
    </>
  );

  const baseClasses = `card transition-all duration-200 hover:shadow-md cursor-pointer ${variantStyles[variant]} border`;

  if (disabled) {
    return (
      <div className={`${baseClasses} opacity-50 cursor-not-allowed`}>
        {content}
      </div>
    );
  }

  if (href) {
    return (
      <a href={href} className={baseClasses}>
        {content}
      </a>
    );
  }

  return (
    <div className={baseClasses} onClick={onClick}>
      {content}
    </div>
  );
}
