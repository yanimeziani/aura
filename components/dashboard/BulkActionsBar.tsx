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
    <div className="sticky top-14 z-20 flex flex-wrap items-center gap-2 sm:gap-3 p-3 sm:p-4 bg-primary/10 border border-primary/20 rounded-xl">
      <span className="text-sm font-semibold w-full sm:w-auto order-first sm:order-none">{t('bulkSelected', { count: selectedIds.length })}</span>
      <button
        onClick={handleBulkOutreach}
        disabled={isPending}
        className="btn btn-sm btn-primary gap-1.5 min-h-[44px] min-w-[44px] touch-manipulation"
      >
        {isPending ? <span className="loading loading-spinner loading-xs" /> : <Mail className="h-3.5 w-3.5" />}
        <span className="truncate">{t('bulkSendOutreach')}</span>
      </button>
      <button
        onClick={handleBulkContacted}
        disabled={isPending}
        className="btn btn-sm btn-outline gap-1.5 min-h-[44px] min-w-[44px] touch-manipulation"
      >
        {isPending ? <span className="loading loading-spinner loading-xs" /> : <CheckCircle2 className="h-3.5 w-3.5" />}
        <span className="truncate">{t('bulkMarkContacted')}</span>
      </button>
      {exportUrl && (
        <a href={exportUrl} className="btn btn-sm btn-ghost gap-1.5 min-h-[44px] min-w-[44px] touch-manipulation" download>
          <Download className="h-3.5 w-3.5" />
          <span className="truncate hidden sm:inline">{t('bulkExportSelected')}</span>
        </a>
      )}
      <button onClick={onClear} className="btn btn-ghost btn-sm btn-square min-h-[44px] min-w-[44px] ml-auto sm:ml-0 touch-manipulation" aria-label={t('dismiss')}>
        <X className="h-4 w-4" />
      </button>
    </div>
  );
}
