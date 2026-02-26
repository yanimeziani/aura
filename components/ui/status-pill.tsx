import { cn } from '../../lib/utils'

type StatusPillVariant = 'recovered' | 'pending' | 'disputed' | 'failed'

const pillStyles: Record<StatusPillVariant, string> = {
  recovered: 'bg-success/10 text-success border-success/20',
  pending: 'bg-muted text-muted-foreground border-border',
  disputed: 'bg-accent text-accent-foreground border-accent/30',
  failed: 'bg-destructive/10 text-destructive border-destructive/20',
}

const pillLabels: Record<StatusPillVariant, { en: string; fr: string }> = {
  recovered: { en: 'Recovered', fr: 'Récupéré' },
  pending: { en: 'Pending', fr: 'En attente' },
  disputed: { en: 'Disputed', fr: 'Contesté' },
  failed: { en: 'Failed', fr: 'Échoué' },
}

interface StatusPillProps {
  variant: StatusPillVariant
  locale?: 'en' | 'fr'
  className?: string
}

export function StatusPill({ variant, locale = 'en', className }: StatusPillProps) {
  return (
    <span
      className={cn(
        'inline-flex items-center px-2.5 py-0.5 text-xs font-medium rounded-sm border transition-fast',
        pillStyles[variant],
        className
      )}
    >
      {pillLabels[variant][locale]}
    </span>
  )
}
