import { ReactNode } from 'react';

/* Components designed with care, not copied */

interface ArticleProps extends React.HTMLAttributes<HTMLElement> {
  children: ReactNode;
}

export function Article({ children, ...props }: ArticleProps) {
  return (
    <article className="prose-dragun" {...props}>
      {children}
    </article>
  );
}

interface CardProps {
  children: ReactNode;
  as?: 'article' | 'section' | 'aside';
  className?: string;
}

export function Card({ children, as = 'article', className = '' }: CardProps) {
  const Tag = as;
  return (
    <Tag className={`border border-quiet bg-base-100 px-8 py-10 shadow-warm ${className}`}>
      {children}
    </Tag>
  );
}

interface ListProps {
  children: ReactNode;
  as?: 'ul' | 'ol';
  className?: string;
}

export function List({ children, as = 'ul', className = '' }: ListProps) {
  const Tag = as;
  return (
    <Tag className={`space-y-4 ${className}`}>
      {children}
    </Tag>
  );
}

interface ListItemProps extends React.LiHTMLAttributes<HTMLLIElement> {
  children: ReactNode;
  icon?: ReactNode;
}

export function ListItem({ children, icon, ...props }: ListItemProps) {
  return (
    <li className="flex gap-4 items-start" {...props}>
      {icon && <span className="flex-shrink-0 mt-0.5">{icon}</span>}
      <span className="flex-1">{children}</span>
    </li>
  );
}

interface DividerProps {
  text?: string;
  className?: string;
}

export function Divider({ text, className = '' }: DividerProps) {
  if (text) {
    return (
      <div className={`flex items-center gap-6 my-20 ${className}`}>
        <div className="flex-1 h-px bg-base-300/40" />
        <span className="text-xs font-medium tracking-[0.2em] uppercase text-base-content/40">
          {text}
        </span>
        <div className="flex-1 h-px bg-base-300/40" />
      </div>
    );
  }

  return <hr className={`my-20 border-base-200 ${className}`} aria-hidden="true" />;
}

interface SectionProps {
  children: ReactNode;
  className?: string;
  variant?: 'default' | 'muted' | 'border';
  padding?: 'none' | 'sm' | 'md' | 'lg';
  id?: string;
}

export function Section({
  children,
  className = '',
  variant = 'default',
  padding = 'lg',
  id,
}: SectionProps) {
  const variantStyles = {
    default: '',
    muted: 'bg-base-200/30',
    border: 'border-y border-base-200',
  };

  const paddingStyles = {
    none: '',
    sm: 'py-12',
    md: 'py-16',
    lg: 'py-20',
  };

  return (
    <section
      id={id}
      className={`${variantStyles[variant]} ${paddingStyles[padding]} ${className}`}
    >
      <div className="app-shell max-w-4xl">{children}</div>
    </section>
  );
}

interface SectionHeaderProps {
  title: string;
  description?: string;
  as?: 'h1' | 'h2' | 'h3';
}

export function SectionHeader({ title, description, as = 'h2' }: SectionHeaderProps) {
  const HeadingTag = as;

  return (
    <div className="mb-16">
      <HeadingTag className="text-2xl md:text-3xl font-medium tracking-tight mb-4">
        {title}
      </HeadingTag>
      {description && (
        <p className="prose-dragun text-lg text-base-content/70">
          {description}
        </p>
      )}
    </div>
  );
}

interface GridProps {
  children: ReactNode;
  cols?: 1 | 2 | 3 | 4;
  gap?: 'sm' | 'md' | 'lg';
  className?: string;
}

export function Grid({ children, cols = 3, gap = 'md', className = '' }: GridProps) {
  const gridCols = {
    1: 'grid-cols-1',
    2: 'md:grid-cols-2',
    3: 'lg:grid-cols-3',
    4: 'lg:grid-cols-4',
  };

  const gapStyles = {
    sm: 'gap-8',
    md: 'gap-12',
    lg: 'gap-16',
  };

  return (
    <div className={`grid ${gridCols[cols]} ${gapStyles[gap]} ${className}`}>
      {children}
    </div>
  );
}

interface BadgeProps {
  children: ReactNode;
  variant?: 'primary' | 'muted';
}

export function Badge({ children, variant = 'muted' }: BadgeProps) {
  const styles = {
    primary: 'bg-primary/10 text-primary px-3 py-1 text-xs font-medium tracking-wider uppercase',
    muted: 'bg-base-200/50 text-base-content/60 px-3 py-1 text-xs font-medium tracking-wider uppercase',
  };

  return <span className={`inline-block ${styles[variant]}`}>{children}</span>;
}
