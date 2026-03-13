import { ReactNode } from 'react';

interface HeroProps {
  title: string;
  description: string;
  primaryButton?: { label: string; href: string };
  secondaryButton?: { label: string; href: string };
  meta?: string;
  variant?: 'default' | 'centered';
}

export function Hero({
  title,
  description,
  primaryButton,
  secondaryButton,
  meta,
  variant = 'default',
}: HeroProps) {
  const isCentered = variant === 'centered';

  return (
    <section className="min-h-[60vh] flex items-center py-20" aria-labelledby="hero-title">
      <div className="container mx-auto px-6 max-w-5xl">
        {meta && (
          <p className="text-sm font-medium tracking-widest uppercase text-base-content/50 mb-4">
            {meta}
          </p>
        )}
        <h1
          id="hero-title"
          className={`text-4xl md:text-5xl lg:text-6xl font-semibold tracking-tight mb-6 ${
            isCentered ? 'text-center' : ''
          }`}
        >
          {title}
        </h1>
        <p
          className={`text-lg md:text-xl text-base-content/70 mb-10 max-w-2xl ${
            isCentered ? 'text-center mx-auto' : ''
          }`}
        >
          {description}
        </p>
        <div className={`flex flex-wrap gap-4 ${isCentered ? 'justify-center' : ''}`}>
          {primaryButton && (
            <a
              href={primaryButton.href}
              className="btn btn-primary btn-lg"
            >
              {primaryButton.label}
            </a>
          )}
          {secondaryButton && (
            <a
              href={secondaryButton.href}
              className="btn btn-ghost btn-lg"
            >
              {secondaryButton.label}
            </a>
          )}
        </div>
      </div>
    </section>
  );
}

interface FeatureCardProps {
  title: string;
  description: string;
  icon?: ReactNode;
  as?: 'article' | 'section';
}

export function FeatureCard({ title, description, icon, as = 'article' }: FeatureCardProps) {
  const Tag = as;

  return (
    <Tag className="group">
      <div className="h-full border border-base-200 bg-base-100 px-6 py-8 transition-colors hover:border-base-300">
        {icon && <div className="mb-4 text-base-content/80">{icon}</div>}
        <h3 className="text-lg font-semibold mb-3">{title}</h3>
        <p className="text-base-content/70 leading-relaxed">{description}</p>
      </div>
    </Tag>
  );
}

interface StatProps {
  label: string;
  value: string | number;
  description?: string;
  as?: 'dl' | 'div';
}

export function Stat({ label, value, description, as = 'dl' }: StatProps) {
  const Tag = as;

  return (
    <Tag>
      <dt className="text-sm font-medium text-base-content/50 mb-1">{label}</dt>
      <dd className="text-4xl md:text-5xl font-semibold tracking-tight mb-2">{value}</dd>
      {description && <dd className="text-base-content/60">{description}</dd>}
    </Tag>
  );
}

interface MetricCardProps {
  title: string;
  value: string | number;
  change?: string;
  positive?: boolean;
}

export function MetricCard({ title, value, change, positive }: MetricCardProps) {
  return (
    <div className="border border-base-200 bg-base-100 px-6 py-6">
      <p className="text-sm font-medium text-base-content/50 mb-2">{title}</p>
      <p className="text-3xl font-semibold tracking-tight mb-1">{value}</p>
      {change && (
        <p className={`text-sm ${positive ? 'text-success' : 'text-error'}`}>
          {change}
        </p>
      )}
    </div>
  );
}

interface ActionCardProps {
  title: string;
  description: string;
  href?: string;
  onClick?: () => void;
  variant?: 'primary' | 'secondary';
}

export function ActionCard({ title, description, href, onClick, variant = 'primary' }: ActionCardProps) {
  const content = (
    <>
      <h3 className="text-lg font-semibold mb-2">{title}</h3>
      <p className="text-base-content/70">{description}</p>
    </>
  );

  const baseClasses = 'border bg-base-100 px-6 py-8 transition-colors hover:border-base-300';

  if (variant === 'primary') {
    return (
      <a href={href} onClick={onClick} className={`${baseClasses} border-primary/20 block`}>
        {content}
      </a>
    );
  }

  return (
    <a href={href} onClick={onClick} className={baseClasses}>
      {content}
    </a>
  );
}
