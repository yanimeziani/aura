import { ReactNode } from 'react';

/* Buttons that feel intentional, not default */

interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  children: ReactNode;
  variant?: 'primary' | 'secondary';
  size?: 'sm' | 'md' | 'lg';
  href?: string;
  icon?: ReactNode;
}

export function Button({ children, variant = 'primary', size = 'md', href, icon, className = '', ...props }: ButtonProps) {
  const baseStyles = 'inline-flex items-center gap-2 font-medium transition-all focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2';

  const sizeStyles = {
    sm: 'px-4 py-2 text-sm',
    md: 'px-6 py-3 text-base',
    lg: 'px-8 py-4 text-lg',
  };

  const variantStyles = {
    primary: 'bg-primary text-primary-content hover:bg-primary/90 focus-visible:ring-primary',
    secondary: 'bg-transparent text-primary border-2 border-base-300 hover:border-base-400 focus-visible:ring-base-400',
  };

  const buttonElement = (
    <button
      className={`${baseStyles} ${sizeStyles[size]} ${variantStyles[variant]} ${className}`}
      {...props}
    >
      {icon && <span aria-hidden="true">{icon}</span>}
      {children}
    </button>
  );

  if (href) {
    return (
      <a href={href} className={className}>
        {buttonElement}
      </a>
    );
  }

  return buttonElement;
}

/* Input components that respect the user */

interface InputProps extends Omit<React.InputHTMLAttributes<HTMLInputElement>, 'size'> {
  label?: string;
  error?: string;
  helper?: string;
  size?: 'sm' | 'md';
}

export function Input({ label, error, helper, size = 'md', className = '', ...props }: InputProps) {
  const sizeStyles = {
    sm: 'px-3 py-2 text-sm',
    md: 'px-4 py-3 text-base',
  };

  const errorState = error ? 'border-error focus:border-error focus:ring-error' : 'focus:border-primary focus:ring-primary';

  return (
    <div className={`space-y-2 ${className}`}>
      {label && (
        <label className="block text-sm font-medium text-base-content">
          {label}
        </label>
      )}
      <input
        {...props}
        className={`w-full border border-base-300 bg-base-100 outline-none transition-all focus:ring-2 focus:ring-offset-0 ${sizeStyles[size]} ${errorState}`}
      />
      {error && <p className="text-sm text-error">{error}</p>}
      {helper && !error && <p className="text-sm text-base-content/60">{helper}</p>}
    </div>
  );
}

interface TextareaProps extends React.TextareaHTMLAttributes<HTMLTextAreaElement> {
  label?: string;
  error?: string;
  helper?: string;
}

export function Textarea({ label, error, helper, className = '', ...props }: TextareaProps) {
  const errorState = error ? 'border-error focus:border-error focus:ring-error' : 'focus:border-primary focus:ring-primary';

  return (
    <div className={`space-y-2 ${className}`}>
      {label && (
        <label className="block text-sm font-medium text-base-content">
          {label}
        </label>
      )}
      <textarea
        {...props}
        className={`w-full border border-base-300 bg-base-100 outline-none transition-all min-h-[120px] p-4 focus:ring-2 focus:ring-offset-0 ${errorState}`}
      />
      {error && <p className="text-sm text-error">{error}</p>}
      {helper && !error && <p className="text-sm text-base-content/60">{helper}</p>}
    </div>
  );
}

/* Link styles that are purposeful */

interface LinkProps extends React.AnchorHTMLAttributes<HTMLAnchorElement> {
  children: ReactNode;
  variant?: 'default' | 'subtle';
}

export function LinkButton({ children, variant = 'default', className = '', ...props }: LinkProps) {
  const styles = {
    default: 'text-primary hover:text-primary/80 underline underline-offset-4 decoration-2',
    subtle: 'text-base-content/70 hover:text-base-content text-primary hover:text-primary/80',
  };

  return (
    <a className={`${styles[variant]} transition-colors ${className}`} {...props}>
      {children}
    </a>
  );
}
