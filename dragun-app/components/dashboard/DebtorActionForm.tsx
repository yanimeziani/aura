'use client';

import { useRef, useState, useTransition } from 'react';
import { useTranslations } from 'next-intl';
import { MoreHorizontal, X, Mail, MailPlus, MessageSquare } from 'lucide-react';
import { COLLECTION_STATUSES } from '@/lib/recovery-types';
import { sendInitialOutreach, sendFollowUp } from '@/app/actions/send-outreach';
import { sendSmsOutreach } from '@/app/actions/send-sms';
import type { DebtorRow } from './dashboard-types';

const OPERATOR_ACTION_TYPES = [
  'status_update',
  'call',
  'sms',
  'follow_up_scheduled',
] as const;

interface Props {
  debtor: DebtorRow;
  handleRecoveryAction: (formData: FormData) => Promise<void>;
}

export default function DebtorActionForm({ debtor, handleRecoveryAction }: Props) {
  const t = useTranslations('Dashboard');
  const dialogRef = useRef<HTMLDialogElement>(null);
  const [isPending, startTransition] = useTransition();
  const [smsType, setSmsType] = useState<'initial' | 'follow_up' | 'reminder'>('initial');

  function handleOpen() {
    dialogRef.current?.showModal();
  }

  function handleClose() {
    dialogRef.current?.close();
  }

  function handleEmail(action: typeof sendInitialOutreach | typeof sendFollowUp) {
    startTransition(async () => {
      const fd = new FormData();
      fd.set('debtor_id', debtor.id);
      const result = await action(fd);
      if (!result.success) {
        alert(result.error || 'Failed');
      }
    });
  }

  function handleSms() {
    startTransition(async () => {
      const fd = new FormData();
      fd.set('debtor_id', debtor.id);
      fd.set('sms_type', smsType);
      const result = await sendSmsOutreach(fd);
      if (!result.success) {
        alert(result.error || 'Failed');
      }
    });
  }

  const hasPhone = !!debtor.phone;

  return (
    <>
      <button
        onClick={handleOpen}
        className="btn btn-sm btn-ghost btn-square"
        aria-label={t('updateStatus')}
      >
        <MoreHorizontal className="h-4 w-4" />
      </button>

      <dialog ref={dialogRef} className="modal modal-bottom sm:modal-middle">
        <div className="modal-box max-w-sm">
          <div className="flex items-center justify-between mb-4">
            <div>
              <h3 className="font-bold text-lg">{debtor.name}</h3>
              <p className="text-sm text-base-content/50">{debtor.email}</p>
              {debtor.phone && (
                <p className="text-sm text-base-content/40">{debtor.phone}</p>
              )}
            </div>
            <button onClick={handleClose} className="btn btn-ghost btn-circle btn-sm">
              <X className="h-4 w-4" />
            </button>
          </div>

          {/* Email outreach */}
          <div className="flex gap-2 mb-3">
            <button
              onClick={() => handleEmail(sendInitialOutreach)}
              disabled={isPending}
              className="btn btn-outline flex-1 gap-1.5 min-h-10"
            >
              {isPending ? (
                <span className="loading loading-spinner loading-xs shrink-0" />
              ) : (
                <Mail className="h-3.5 w-3.5 shrink-0" />
              )}
              {t('emailOutreach')}
            </button>
            <button
              onClick={() => handleEmail(sendFollowUp)}
              disabled={isPending}
              className="btn btn-outline flex-1 gap-1.5 min-h-10"
            >
              {isPending ? (
                <span className="loading loading-spinner loading-xs shrink-0" />
              ) : (
                <MailPlus className="h-3.5 w-3.5 shrink-0" />
              )}
              {t('emailFollowUp')}
            </button>
          </div>

          {/* SMS outreach */}
          <div className="flex gap-2 mb-4">
            <select
              value={smsType}
              onChange={(e) => setSmsType(e.target.value as typeof smsType)}
              className="select select-bordered select-sm flex-1 min-h-10"
            >
              <option value="initial">{t('smsInitial')}</option>
              <option value="follow_up">{t('smsFollowUp')}</option>
              <option value="reminder">{t('smsReminder')}</option>
            </select>
            <button
              onClick={handleSms}
              disabled={isPending || !hasPhone}
              className="btn btn-outline gap-1.5 min-h-10"
              title={hasPhone ? t('sendSmsTitle') : t('noPhoneWarning')}
            >
              {isPending ? (
                <span className="loading loading-spinner loading-xs" />
              ) : (
                <MessageSquare className="h-3.5 w-3.5" />
              )}
              {t('sendBtn')}
            </button>
          </div>

          {!hasPhone && (
            <p className="text-xs text-warning mb-3">{t('noPhoneWarning')}</p>
          )}

          <div className="divider text-label my-2">{t('updateStatus')}</div>

          <form
            action={async (fd) => {
              await handleRecoveryAction(fd);
              handleClose();
            }}
            className="space-y-3"
          >
            <input type="hidden" name="debtor_id" value={debtor.id} />

            <div className="form-control">
              <label className="text-label mb-1">{t('actionType')}</label>
              <select
                name="action_type"
                defaultValue="status_update"
                className="select select-bordered select-sm w-full min-h-10"
              >
                {OPERATOR_ACTION_TYPES.map((a) => (
                  <option key={a} value={a}>
                    {a.replace(/_/g, ' ')}
                  </option>
                ))}
              </select>
            </div>

            <div className="form-control">
              <label className="text-label mb-1">{t('newStatus')}</label>
              <select
                name="status"
                defaultValue={debtor.status}
                className="select select-bordered select-sm w-full min-h-10"
              >
                {COLLECTION_STATUSES.map((s) => (
                  <option key={s} value={s}>
                    {s.replace(/_/g, ' ')}
                  </option>
                ))}
              </select>
            </div>

            <div className="form-control">
              <label className="text-label mb-1">{t('noteLabel')}</label>
              <input
                name="note"
                placeholder={t('notePlaceholder')}
                className="input input-bordered input-sm w-full min-h-10"
              />
            </div>

            <label className="flex items-center gap-2 cursor-pointer">
              <input
                type="checkbox"
                name="confirm_escalated"
                value="yes"
                className="checkbox checkbox-xs checkbox-warning"
              />
              <span className="text-xs text-base-content/60">
                {t('confirmEscalation')}
              </span>
            </label>

            <button type="submit" className="btn btn-primary w-full mt-2 min-h-11">
              {t('save')}
            </button>
          </form>
        </div>
        <form method="dialog" className="modal-backdrop bg-base-100/80 backdrop-blur-sm">
          <button type="submit" onClick={handleClose}>
            close
          </button>
        </form>
      </dialog>
    </>
  );
}
