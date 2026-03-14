import { ReactNode } from 'react';

interface InputProps {
  label?: string;
  type?: 'text' | 'email' | 'password' | 'number' | 'tel' | 'url' | 'search';
  placeholder?: string;
  value?: string | number;
  onChange?: (value: string) => void;
  disabled?: boolean;
  required?: boolean;
  error?: string;
  helper?: string;
  icon?: ReactNode;
  iconPosition?: 'left' | 'right';
  size?: 'xs' | 'sm' | 'md' | 'lg';
  bordered?: boolean;
  className?: string;
  name?: string;
}

export function Input({
  label,
  type = 'text',
  placeholder,
  value,
  onChange,
  disabled = false,
  required = false,
  error,
  helper,
  icon,
  iconPosition = 'left',
  size = 'md',
  bordered = true,
  className = '',
  name,
}: InputProps) {
  const sizeClasses = {
    xs: 'input input-xs',
    sm: 'input input-sm',
    md: 'input',
    lg: 'input input-lg',
  };

  const borderedClass = bordered ? '' : 'input-bordered';
  const errorClass = error ? 'input-error' : '';

  return (
    <div className={`form-control w-full ${className}`}>
      {label && (
        <label className="label">
          <span className="label-text">{label}</span>
          {required && <span className="label-text-alt text-error">*</span>}
        </label>
      )}
      <div className={`relative ${icon ? 'join' : ''}`}>
        {icon && iconPosition === 'left' && (
          <span className="join-item flex items-center justify-center px-3 bg-base-200 border border-base-300 rounded-l-lg">
            {icon}
          </span>
        )}
        <input
          type={type}
          name={name}
          placeholder={placeholder}
          value={value}
          onChange={(e) => onChange?.(e.target.value)}
          disabled={disabled}
          className={`${sizeClasses[size]} ${borderedClass} ${errorClass} w-full ${icon && iconPosition === 'left' ? 'rounded-none border-l-0' : ''} ${icon && iconPosition === 'right' ? 'rounded-r-none' : ''}`}
          required={required}
        />
        {icon && iconPosition === 'right' && (
          <span className="join-item flex items-center justify-center px-3 bg-base-200 border border-base-300 rounded-r-lg">
            {icon}
          </span>
        )}
      </div>
      {error && <span className="label-text-alt text-error">{error}</span>}
      {helper && !error && <span className="label-text-alt">{helper}</span>}
    </div>
  );
}

interface TextareaProps {
  label?: string;
  placeholder?: string;
  value?: string;
  onChange?: (value: string) => void;
  disabled?: boolean;
  required?: boolean;
  error?: string;
  helper?: string;
  rows?: number;
  size?: 'xs' | 'sm' | 'md' | 'lg';
  bordered?: boolean;
  resize?: 'none' | 'both' | 'horizontal' | 'vertical';
  className?: string;
  name?: string;
}

export function Textarea({
  label,
  placeholder,
  value,
  onChange,
  disabled = false,
  required = false,
  error,
  helper,
  rows = 4,
  size = 'md',
  bordered = true,
  resize = 'vertical',
  className = '',
  name,
}: TextareaProps) {
  const sizeClasses = {
    xs: 'textarea textarea-xs',
    sm: 'textarea textarea-sm',
    md: 'textarea',
    lg: 'textarea textarea-lg',
  };

  const borderedClass = bordered ? '' : 'textarea-bordered';
  const errorClass = error ? 'textarea-error' : '';
  const resizeClass = resize === 'none' ? 'resize-none' : resize === 'both' ? 'resize' : `resize-${resize}`;

  return (
    <div className={`form-control w-full ${className}`}>
      {label && (
        <label className="label">
          <span className="label-text">{label}</span>
          {required && <span className="label-text-alt text-error">*</span>}
        </label>
      )}
      <textarea
        name={name}
        placeholder={placeholder}
        value={value}
        onChange={(e) => onChange?.(e.target.value)}
        disabled={disabled}
        rows={rows}
        className={`${sizeClasses[size]} ${borderedClass} ${errorClass} ${resizeClass} w-full`}
        required={required}
      />
      {error && <span className="label-text-alt text-error">{error}</span>}
      {helper && !error && <span className="label-text-alt">{helper}</span>}
    </div>
  );
}

interface SelectProps {
  label?: string;
  placeholder?: string;
  value?: string;
  onChange?: (value: string) => void;
  options: { value: string; label: string; disabled?: boolean }[];
  disabled?: boolean;
  required?: boolean;
  error?: string;
  helper?: string;
  size?: 'xs' | 'sm' | 'md' | 'lg';
  bordered?: boolean;
  className?: string;
  name?: string;
}

export function Select({
  label,
  placeholder = 'Select an option',
  value,
  onChange,
  options,
  disabled = false,
  required = false,
  error,
  helper,
  size = 'md',
  bordered = true,
  className = '',
  name,
}: SelectProps) {
  const sizeClasses = {
    xs: 'select select-xs',
    sm: 'select select-sm',
    md: 'select',
    lg: 'select select-lg',
  };

  const borderedClass = bordered ? '' : 'select-bordered';
  const errorClass = error ? 'select-error' : '';

  return (
    <div className={`form-control w-full ${className}`}>
      {label && (
        <label className="label">
          <span className="label-text">{label}</span>
          {required && <span className="label-text-alt text-error">*</span>}
        </label>
      )}
      <select
        name={name}
        value={value}
        onChange={(e) => onChange?.(e.target.value)}
        disabled={disabled}
        className={`${sizeClasses[size]} ${borderedClass} ${errorClass} w-full`}
        required={required}
      >
        <option value="" disabled>
          {placeholder}
        </option>
        {options.map((option) => (
          <option key={option.value} value={option.value} disabled={option.disabled}>
            {option.label}
          </option>
        ))}
      </select>
      {error && <span className="label-text-alt text-error">{error}</span>}
      {helper && !error && <span className="label-text-alt">{helper}</span>}
    </div>
  );
}

interface CheckboxProps {
  label?: string;
  checked: boolean;
  onChange: (checked: boolean) => void;
  disabled?: boolean;
  indeterminate?: boolean;
  error?: string;
  size?: 'xs' | 'sm' | 'md' | 'lg';
  variant?: 'default' | 'primary' | 'secondary' | 'accent' | 'success' | 'warning' | 'info';
  className?: string;
  name?: string;
}

export function Checkbox({
  label,
  checked,
  onChange,
  disabled = false,
  indeterminate = false,
  error,
  size = 'md',
  variant = 'default',
  className = '',
  name,
}: CheckboxProps) {
  const sizeClasses = {
    xs: 'checkbox checkbox-xs',
    sm: 'checkbox checkbox-sm',
    md: 'checkbox',
    lg: 'checkbox checkbox-lg',
  };

  const variantClass = variant === 'default' ? '' : `checkbox-${variant}`;
  const errorClass = error ? 'checkbox-error' : '';

  return (
    <div className={`form-control ${className}`}>
      <label className="label cursor-pointer justify-start gap-3">
        <input
          type="checkbox"
          name={name}
          className={`${sizeClasses[size]} ${variantClass} ${errorClass}`}
          checked={checked}
          onChange={(e) => onChange?.(e.target.checked)}
          disabled={disabled}
          ref={(ref) => {
            if (ref && indeterminate) {
              ref.indeterminate = true;
            }
          }}
        />
        {label && (
          <span className={`label-text ${disabled ? 'text-base-content/40' : ''} ${error ? 'text-error' : ''}`}>
            {label}
          </span>
        )}
      </label>
      {error && <span className="label-text-alt text-error pl-9">{error}</span>}
    </div>
  );
}

interface RadioProps {
  label?: string;
  name: string;
  value: string;
  checked: boolean;
  onChange: (value: string) => void;
  disabled?: boolean;
  error?: string;
  size?: 'xs' | 'sm' | 'md' | 'lg';
  variant?: 'default' | 'primary' | 'secondary' | 'accent';
  className?: string;
}

export function Radio({
  label,
  name,
  value,
  checked,
  onChange,
  disabled = false,
  error,
  size = 'md',
  variant = 'default',
  className = '',
}: RadioProps) {
  const sizeClasses = {
    xs: 'radio radio-xs',
    sm: 'radio radio-sm',
    md: 'radio',
    lg: 'radio radio-lg',
  };

  const variantClass = variant === 'default' ? '' : `radio-${variant}`;
  const errorClass = error ? 'radio-error' : '';

  return (
    <div className={`form-control ${className}`}>
      <label className="label cursor-pointer justify-start gap-3">
        <input
          type="radio"
          name={name}
          className={`${sizeClasses[size]} ${variantClass} ${errorClass}`}
          value={value}
          checked={checked}
          onChange={() => onChange?.(value)}
          disabled={disabled}
        />
        {label && (
          <span className={`label-text ${disabled ? 'text-base-content/40' : ''}`}>
            {label}
          </span>
        )}
      </label>
    </div>
  );
}

interface RadioGroupProps {
  label?: string;
  name: string;
  value: string;
  onChange: (value: string) => void;
  options: { value: string; label: string; disabled?: boolean }[];
  disabled?: boolean;
  error?: string;
  orientation?: 'vertical' | 'horizontal';
  size?: 'xs' | 'sm' | 'md' | 'lg';
  variant?: 'default' | 'primary' | 'secondary' | 'accent';
  className?: string;
}

export function RadioGroup({
  label,
  name,
  value,
  onChange,
  options,
  disabled = false,
  error,
  orientation = 'vertical',
  size = 'md',
  variant = 'default',
  className = '',
}: RadioGroupProps) {
  return (
    <div className={`form-control w-full ${className}`}>
      {label && (
        <label className="label">
          <span className="label-text">{label}</span>
        </label>
      )}
      <div className={orientation === 'vertical' ? 'flex flex-col gap-2' : 'flex flex-wrap gap-4'}>
        {options.map((option) => (
          <Radio
            key={option.value}
            name={name}
            value={option.value}
            label={option.label}
            checked={value === option.value}
            onChange={onChange}
            disabled={disabled || option.disabled}
            size={size}
            variant={variant}
          />
        ))}
      </div>
      {error && <span className="label-text-alt text-error">{error}</span>}
    </div>
  );
}

interface RangeProps {
  label?: string;
  value: number;
  onChange: (value: number) => void;
  min?: number;
  max?: number;
  step?: number;
  disabled?: boolean;
  error?: string;
  helper?: string;
  showValue?: boolean;
  size?: 'xs' | 'sm' | 'md' | 'lg';
  className?: string;
  name?: string;
}

export function Range({
  label,
  value,
  onChange,
  min = 0,
  max = 100,
  step = 1,
  disabled = false,
  error,
  helper,
  showValue = false,
  size = 'md',
  className = '',
  name,
}: RangeProps) {
  const sizeClasses = {
    xs: 'range range-xs',
    sm: 'range range-sm',
    md: 'range',
    lg: 'range range-lg',
  };

  const errorClass = error ? 'range-error' : '';

  return (
    <div className={`form-control w-full ${className}`}>
      {label && (
        <label className="label">
          <span className="label-text">{label}</span>
          {showValue && <span className="label-text-alt font-semibold">{value}</span>}
        </label>
      )}
      <input
        type="range"
        name={name}
        min={min}
        max={max}
        step={step}
        value={value}
        onChange={(e) => onChange?.(Number(e.target.value))}
        disabled={disabled}
        className={`${sizeClasses[size]} ${errorClass} w-full`}
      />
      {error && <span className="label-text-alt text-error">{error}</span>}
      {helper && !error && <span className="label-text-alt">{helper}</span>}
    </div>
  );
}
