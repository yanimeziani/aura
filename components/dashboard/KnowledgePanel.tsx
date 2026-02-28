import { FileText, Plus } from 'lucide-react';

interface Props {
  contract: { file_name: string } | null;
  handleUpload: (formData: FormData) => Promise<void>;
  t: (key: string) => string;
}

export default function KnowledgePanel({ contract, handleUpload, t }: Props) {
  return (
    <div className="card bg-base-200/50 border border-base-300/50 shadow-warm">
      <div className="card-body p-5">
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center gap-3">
            <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-base-300/50">
              <FileText className="h-4 w-4 text-base-content/60" />
            </div>
            <h2 className="font-bold">{t('ragContext')}</h2>
          </div>
          {contract && (
            <span className="badge badge-success badge-sm gap-1">
              {t('active')}
            </span>
          )}
        </div>

        <form action={handleUpload} className="space-y-3">
          <input
            id="contract-upload"
            type="file"
            name="contract"
            accept=".pdf"
            className="hidden"
          />
          <label
            htmlFor="contract-upload"
            className="flex h-24 w-full cursor-pointer flex-col items-center justify-center gap-2 rounded-xl border-2 border-dashed border-base-300 bg-base-100 text-base-content/40 transition-colors hover:border-primary hover:text-primary"
          >
            <Plus className="h-5 w-5" />
            <span className="text-label">{t('replacePDF')}</span>
          </label>
          <button className="btn btn-ghost w-full min-h-10">
            {t('executeIndexing')}
          </button>
        </form>

        {contract && (
          <div className="mt-3 rounded-lg border border-base-300/50 bg-base-100 p-3">
            <p className="text-label">{t('currentFile')}</p>
            <p className="mt-1 truncate text-sm font-medium">{contract.file_name}</p>
          </div>
        )}
      </div>
    </div>
  );
}
