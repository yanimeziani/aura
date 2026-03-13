'use client';

import { useRef, useState, useTransition } from 'react';
import { useTranslations } from 'next-intl';
import { Upload, X, CheckCircle2, AlertTriangle, FileSpreadsheet } from 'lucide-react';
import { importDebtors } from '@/app/actions/import-debtors';

export default function ImportDebtors() {
  const t = useTranslations('Dashboard');
  const dialogRef = useRef<HTMLDialogElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [file, setFile] = useState<File | null>(null);
  const [isPending, startTransition] = useTransition();
  const [result, setResult] = useState<{
    success: boolean;
    imported: number;
    errors: string[];
    outreachSent?: number;
  } | null>(null);
  const [autoSendOutreach, setAutoSendOutreach] = useState(true);

  function handleImport() {
    if (!file) return;
    const formData = new FormData();
    formData.append('csv', file);
    formData.append('auto_send_outreach', String(autoSendOutreach));

    startTransition(async () => {
      const res = await importDebtors(formData);
      setResult(res);
      if (res.success) {
        setFile(null);
        if (fileInputRef.current) fileInputRef.current.value = '';
      }
    });
  }

  function handleClose() {
    dialogRef.current?.close();
    setResult(null);
    setFile(null);
  }

  return (
    <>
      <button
        onClick={() => dialogRef.current?.showModal()}
        className="btn btn-ghost min-h-10 gap-2 px-4 text-[11px] font-semibold uppercase tracking-[0.14em]"
      >
        <Upload className="h-3.5 w-3.5" />
        {t('importCsv')}
      </button>

      <dialog ref={dialogRef} className="modal modal-bottom sm:modal-middle">
        <div className="modal-box overflow-hidden rounded-2xl border border-base-300 bg-base-200 p-0 shadow-xl">
          <div className="p-6">
            <div className="mb-6 flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="flex h-11 w-11 items-center justify-center rounded-xl border border-base-300 bg-base-100">
                  <FileSpreadsheet className="h-5 w-5" />
                </div>
                <div>
                  <h3 className="text-lg font-semibold uppercase tracking-[0.12em]">{t('importDebtorsTitle')}</h3>
                  <p className="text-label">{t('importSubtitle')}</p>
                </div>
              </div>
              <button onClick={handleClose} className="btn btn-ghost btn-circle btn-sm">
                <X className="h-4 w-4" />
              </button>
            </div>

            {result && (
              <div className={`alert ${result.success ? 'alert-success' : 'alert-error'} mb-4`}>
                {result.success ? <CheckCircle2 className="h-5 w-5" /> : <AlertTriangle className="h-5 w-5" />}
                <div>
                  {result.success ? (
                    <>
                      <p className="font-semibold">{t('importSuccess', { count: result.imported })}</p>
                      {result.outreachSent !== undefined && result.outreachSent > 0 && (
                        <p className="text-xs mt-1">{t('outreachSent', { count: result.outreachSent })}</p>
                      )}
                    </>
                  ) : (
                    <p className="font-semibold">{t('importFailed')}</p>
                  )}
                  {result.errors.map((e, i) => (
                    <p key={i} className="text-xs mt-1">{e}</p>
                  ))}
                </div>
              </div>
            )}

            <div className="space-y-4">
              <div>
                <input
                  ref={fileInputRef}
                  type="file"
                  accept=".csv"
                  onChange={(e) => { setFile(e.target.files?.[0] || null); setResult(null); }}
                  className="file-input file-input-bordered w-full min-h-11"
                />
              </div>

              <label className="flex items-center gap-3 cursor-pointer">
                <input
                  type="checkbox"
                  checked={autoSendOutreach}
                  onChange={(e) => setAutoSendOutreach(e.target.checked)}
                  className="checkbox checkbox-primary checkbox-sm"
                />
                <span className="text-sm">{t('autoSendOutreach')}</span>
              </label>

              <div className="rounded-xl border border-base-300 bg-base-100 p-4 space-y-2">
                <p className="text-label">{t('requiredColumns')}</p>
                <p className="text-xs text-base-content/60">
                  <code className="bg-base-300 px-1.5 py-0.5 rounded text-[10px]">name</code>,{' '}
                  <code className="bg-base-300 px-1.5 py-0.5 rounded text-[10px]">email</code>,{' '}
                  <code className="bg-base-300 px-1.5 py-0.5 rounded text-[10px]">total_debt</code>
                </p>
                <p className="text-label mt-2">{t('optionalColumns')}</p>
                <p className="text-xs text-base-content/60">
                  <code className="bg-base-300 px-1.5 py-0.5 rounded text-[10px]">phone</code>,{' '}
                  <code className="bg-base-300 px-1.5 py-0.5 rounded text-[10px]">currency</code>,{' '}
                  <code className="bg-base-300 px-1.5 py-0.5 rounded text-[10px]">days_overdue</code>
                </p>
              </div>

              <button
                onClick={handleImport}
                disabled={!file || isPending}
                className="btn btn-primary w-full min-h-12"
              >
                {isPending ? <span className="loading loading-spinner loading-sm" /> : (
                  <>
                    <Upload className="h-4 w-4" />
                    {t('importButton')} {file ? `(${file.name})` : ''}
                  </>
                )}
              </button>
            </div>
          </div>
        </div>
        <form method="dialog" className="modal-backdrop bg-base-100/80 backdrop-blur-sm">
          <button type="submit">close</button>
        </form>
      </dialog>
    </>
  );
}
