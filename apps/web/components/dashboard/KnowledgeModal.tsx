'use client';

import { useActionState, useEffect } from 'react';
import { useTranslations } from 'next-intl';
import { FileText, Plus, X } from 'lucide-react';
import AccessibleModal from '@/components/ui/AccessibleModal';
import { uploadContractFromForm } from '@/app/actions/upload-contract';

interface Props {
  open: boolean;
  onClose: () => void;
  contract: { file_name: string } | null;
}

export default function KnowledgeModal({ open, onClose, contract }: Props) {
  const t = useTranslations('Dashboard');
  const [state, formAction, isPending] = useActionState(uploadContractFromForm, {
    success: false,
    error: undefined as string | undefined,
  });

  useEffect(() => {
    if (state.success) onClose();
  }, [state.success, onClose]);

  return (
    <AccessibleModal
      open={open}
      onClose={onClose}
      titleId="knowledge-modal-title"
      className="max-w-md"
      closeAriaLabel={t('closeModal')}
    >
      <div className="flex items-center justify-between gap-2 border-b border-base-300/50 px-4 pt-4 pb-4 sm:px-6 sm:pt-6">
        <div className="flex min-w-0 flex-1 items-center gap-3">
          <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-base-300/50">
            <FileText className="h-4 w-4 text-base-content/60" />
          </div>
          <h2 id="knowledge-modal-title" className="font-bold truncate">
            {t('ragContext')}
          </h2>
          {contract && (
            <span className="badge badge-success badge-sm shrink-0">{t('active')}</span>
          )}
        </div>
        <button
          type="button"
          onClick={onClose}
          className="btn btn-ghost btn-circle btn-sm shrink-0"
          aria-label={t('cancel')}
        >
          <X className="h-4 w-4" />
        </button>
      </div>

      <form action={formAction} className="space-y-3 px-4 pb-6 pt-4 sm:px-6 sm:pb-8">
        <input
          id="knowledge-contract-upload"
          type="file"
          name="contract"
          accept=".pdf"
          className="hidden"
        />
        <label
          htmlFor="knowledge-contract-upload"
          className="flex h-24 w-full cursor-pointer flex-col items-center justify-center gap-2 rounded-xl border-2 border-dashed border-base-300 bg-base-100 text-base-content/40 transition-colors hover:border-primary hover:text-primary"
        >
          <Plus className="h-5 w-5" />
          <span className="text-label">{t('replacePDF')}</span>
        </label>
        <button
          type="submit"
          className="btn btn-ghost w-full min-h-10"
          disabled={isPending}
        >
          {isPending ? (
            <span className="loading loading-spinner loading-sm" />
          ) : (
            t('executeIndexing')
          )}
        </button>
      </form>

      {state.error && (
        <p className="mt-3 text-sm text-error" role="alert">
          {state.error}
        </p>
      )}

      {contract && (
        <div className="mt-3 rounded-lg border border-base-300/50 bg-base-100 p-3">
          <p className="text-label">{t('currentFile')}</p>
          <p className="mt-1 truncate text-sm font-medium">{contract.file_name}</p>
        </div>
      )}
    </AccessibleModal>
  );
}
