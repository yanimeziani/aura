import { ReactNode } from 'react';

/* Typography components for respectful communication */

interface HeadingProps extends React.HTMLAttributes<HTMLElement> {
  children: ReactNode;
  as?: 'h1' | 'h2' | 'h3' | 'h4';
  size?: 'sm' | 'md' | 'lg' | 'xl';
  weight?: 'normal' | 'medium' | 'semibold';
}

export function Heading({ children, as = 'h2', size = 'lg', weight = 'semibold', className = '', ...props }: HeadingProps) {
  const Tag = as;

  const sizeStyles = {
    sm: 'text-xl',
    md: 'text-2xl',
    lg: 'text-3xl md:text-4xl',
    xl: 'text-4xl md:text-5xl lg:text-6xl',
  };

  const weightStyles = {
    normal: 'font-normal',
    medium: 'font-medium',
    semibold: 'font-semibold',
  };

  return (
    <Tag className={`${sizeStyles[size]} ${weightStyles[weight]} tracking-tight ${className}`} {...props}>
      {children}
    </Tag>
  );
}

interface TextProps extends React.HTMLAttributes<HTMLElement> {
  children: ReactNode;
  size?: 'sm' | 'md' | 'lg';
  muted?: boolean;
  as?: 'p' | 'span' | 'div';
}

export function Text({ children, size = 'md', muted = false, as = 'p', className = '', ...props }: TextProps) {
  const Tag = as;

  const sizeStyles = {
    sm: 'text-sm',
    md: 'text-base',
    lg: 'text-lg',
  };

  const colorStyles = muted ? 'text-base-content/60' : 'text-base-content/90';

  return (
    <Tag className={`${sizeStyles[size]} ${colorStyles} leading-relaxed ${className}`} {...props}>
      {children}
    </Tag>
  );
}

interface LabelProps extends React.LabelHTMLAttributes<HTMLLabelElement> {
  children: ReactNode;
  required?: boolean;
  /** Aria-label for the required asterisk (for i18n, e.g. t('required')). */
  requiredAriaLabel?: string;
}

export function Label({ children, required = false, requiredAriaLabel = 'required', className = '', ...props }: LabelProps) {
  return (
    <label className={`block text-sm font-medium text-base-content mb-2 ${className}`} {...props}>
      {children}
      {required && <span className="text-error ml-1" aria-label={requiredAriaLabel}>*</span>}
    </label>
  );
}
