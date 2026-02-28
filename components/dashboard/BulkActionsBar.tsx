'use client';

import { useTransition } from 'react';
import { useTranslations } from 'next-intl';
import { Mail, CheckCircle2, X, Download } from 'lucide-react';
import { bulkSendOutreach, bulkMarkContacted } from '@/app/actions/bulk-actions';

interface Props {
  selectedIds: string[];
  onClear: () => void;
  onDone: () => void;
}

export default function BulkActionsBar({ selectedIds, onClear, onDone }: Props) {
  const t = useTranslations('Dashboard');
  const [isPending, startTransition] = useTransition();

  const exportUrl = selectedIds.length
    ? `/api/recovery/export?ids=${encodeURIComponent(selectedIds.join(','))}`
    : null;

  function handleBulkOutreach() {
    startTransition(async () => {
      const res = await bulkSendOutreach(selectedIds);
      if (res.sent > 0) {
        alert(res.sent === selectedIds.length ? t('bulkOutreachSuccess', { count: res.sent }) : `${res.sent} sent. ${res.errors.join('; ')}`);
        onDone();
      } else if (res.errors.length) {
        alert(res.errors.join('\n'));
      }
    });
  }

  function handleBulkContacted() {
    startTransition(async () => {
      const res = await bulkMarkContacted(selectedIds);
      if (res.updated > 0) {
        alert(t('bulkContactedSuccess', { count: res.updated }));
        onDone();
      } else if (res.errors.length) {
        alert(res.errors.join('\n'));
      }
    });
  }

  return (
    <div className="flex flex-wrap items-center gap-3 p-4 bg-primary/10 border border-primary/20 rounded-xl">
      <span className="text-sm font-semibold">{t('bulkSelected', { count: selectedIds.length })}</span>
      <button
        onClick={handleBulkOutreach}
        disabled={isPending}
        className="btn btn-sm btn-primary gap-1.5 min-h-9"
      >
        {isPending ? <span className="loading loading-spinner loading-xs" /> : <Mail className="h-3.5 w-3.5" />}
        {t('bulkSendOutreach')}
      </button>
      <button
        onClick={handleBulkContacted}
        disabled={isPending}
        className="btn btn-sm btn-outline gap-1.5 min-h-9"
      >
        {isPending ? <span className="loading loading-spinner loading-xs" /> : <CheckCircle2 className="h-3.5 w-3.5" />}
        {t('bulkMarkContacted')}
      </button>
      {exportUrl && (
        <a href={exportUrl} className="btn btn-sm btn-ghost gap-1.5 min-h-9" download>
          <Download className="h-3.5 w-3.5" />
          {t('bulkExportSelected')}
        </a>
      )}
      <button onClick={onClear} className="btn btn-ghost btn-sm btn-square">
        <X className="h-4 w-4" />
      </button>
    </div>
  );
}
