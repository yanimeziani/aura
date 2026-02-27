'use client';

import { useRef, useTransition } from 'react';
import { MoreHorizontal, X, Mail, MailPlus } from 'lucide-react';
import { COLLECTION_STATUSES } from '@/lib/recovery-types';
import { sendInitialOutreach, sendFollowUp } from '@/app/actions/send-outreach';
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
  const dialogRef = useRef<HTMLDialogElement>(null);
  const [isPending, startTransition] = useTransition();

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
        alert(result.error || 'Email failed');
      }
    });
  }

  return (
    <>
      <button
        onClick={handleOpen}
        className="btn btn-sm btn-ghost btn-square"
        aria-label="Update status"
      >
        <MoreHorizontal className="h-4 w-4" />
      </button>

      <dialog ref={dialogRef} className="modal modal-bottom sm:modal-middle">
        <div className="modal-box max-w-sm">
          <div className="flex items-center justify-between mb-4">
            <div>
              <h3 className="font-bold text-lg">{debtor.name}</h3>
              <p className="text-sm text-base-content/50">{debtor.email}</p>
            </div>
            <button onClick={handleClose} className="btn btn-ghost btn-circle btn-sm">
              <X className="h-4 w-4" />
            </button>
          </div>

          {/* Email outreach buttons */}
          <div className="flex gap-2 mb-4">
            <button
              onClick={() => handleEmail(sendInitialOutreach)}
              disabled={isPending}
              className="btn btn-sm btn-outline flex-1 gap-1.5"
            >
              {isPending ? (
                <span className="loading loading-spinner loading-xs" />
              ) : (
                <Mail className="h-3.5 w-3.5" />
              )}
              Initial Outreach
            </button>
            <button
              onClick={() => handleEmail(sendFollowUp)}
              disabled={isPending}
              className="btn btn-sm btn-outline flex-1 gap-1.5"
            >
              {isPending ? (
                <span className="loading loading-spinner loading-xs" />
              ) : (
                <MailPlus className="h-3.5 w-3.5" />
              )}
              Follow Up
            </button>
          </div>

          <div className="divider text-label my-2">Update Status</div>

          <form
            action={async (fd) => {
              await handleRecoveryAction(fd);
              handleClose();
            }}
            className="space-y-3"
          >
            <input type="hidden" name="debtor_id" value={debtor.id} />

            <div className="form-control">
              <label className="text-label mb-1">Action Type</label>
              <select
                name="action_type"
                defaultValue="status_update"
                className="select select-bordered select-sm w-full"
              >
                {OPERATOR_ACTION_TYPES.map((a) => (
                  <option key={a} value={a}>
                    {a.replace(/_/g, ' ')}
                  </option>
                ))}
              </select>
            </div>

            <div className="form-control">
              <label className="text-label mb-1">New Status</label>
              <select
                name="status"
                defaultValue={debtor.status}
                className="select select-bordered select-sm w-full"
              >
                {COLLECTION_STATUSES.map((s) => (
                  <option key={s} value={s}>
                    {s.replace(/_/g, ' ')}
                  </option>
                ))}
              </select>
            </div>

            <div className="form-control">
              <label className="text-label mb-1">Note (optional)</label>
              <input
                name="note"
                placeholder="Add a note..."
                className="input input-bordered input-sm w-full"
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
                Confirm escalation (required for escalated status)
              </span>
            </label>

            <button type="submit" className="btn btn-primary btn-sm w-full mt-2">
              Save
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
