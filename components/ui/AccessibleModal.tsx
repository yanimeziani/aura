'use client';

import { useRef, useEffect, useCallback } from 'react';

interface Props {
  open: boolean;
  onClose: () => void;
  /** ID of the element that labels the dialog (e.g. modal title). */
  titleId: string;
  /** Optional description ID for aria-describedby. */
  descriptionId?: string;
  children: React.ReactNode;
  /** Optional class for the modal-box (e.g. max-w-lg). */
  className?: string;
}

const FOCUSABLE =
  'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])';

export default function AccessibleModal({
  open,
  onClose,
  titleId,
  descriptionId,
  children,
  className = '',
}: Props) {
  const dialogRef = useRef<HTMLDialogElement>(null);
  const previousActiveRef = useRef<Element | null>(null);

  const close = useCallback(() => {
    dialogRef.current?.close();
    onClose();
  }, [onClose]);

  useEffect(() => {
    if (!open) return;
    previousActiveRef.current = document.activeElement;
    dialogRef.current?.showModal();
    return () => {
      if (previousActiveRef.current && previousActiveRef.current instanceof HTMLElement) {
        previousActiveRef.current.focus();
      }
    };
  }, [open]);

  useEffect(() => {
    if (!open || !dialogRef.current) return;
    const dialog = dialogRef.current;

    function onEscape(e: KeyboardEvent) {
      if (e.key === 'Escape') {
        e.preventDefault();
        close();
      }
    }

    function onKeyDown(e: KeyboardEvent) {
      if (e.key !== 'Tab') return;
      const focusable = Array.from(dialog.querySelectorAll<HTMLElement>(FOCUSABLE));
      const first = focusable[0];
      const last = focusable[focusable.length - 1];
      if (e.shiftKey) {
        if (document.activeElement === first) {
          e.preventDefault();
          last?.focus();
        }
      } else {
        if (document.activeElement === last) {
          e.preventDefault();
          first?.focus();
        }
      }
    }

    document.addEventListener('keydown', onEscape);
    dialog.addEventListener('keydown', onKeyDown);
    return () => {
      document.removeEventListener('keydown', onEscape);
      dialog.removeEventListener('keydown', onKeyDown);
    };
  }, [open, close]);

  if (!open) return null;

  return (
    <dialog
      ref={dialogRef}
      className="modal modal-bottom sm:modal-middle"
      role="dialog"
      aria-modal="true"
      aria-labelledby={titleId}
      aria-describedby={descriptionId}
      onCancel={close}
    >
      <div className={`modal-box overflow-hidden rounded-2xl border border-base-300 bg-base-200 shadow-xl ${className}`}>
        {children}
      </div>
      <form method="dialog" className="modal-backdrop bg-base-100/80 backdrop-blur-sm" onSubmit={close}>
        <button type="submit" className="cursor-default" aria-label="Close modal" />
      </form>
    </dialog>
  );
}
