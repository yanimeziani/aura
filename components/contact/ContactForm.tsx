'use client';

import { useActionState } from 'react';
import { useTranslations } from 'next-intl';
import { Send, Mail, User, Tag, MessageSquare, CheckCircle2, AlertCircle } from 'lucide-react';
import { submitContact } from '@/app/actions/contact';

const SUBJECT_OPTIONS = [
  { value: 'general', labelKey: 'subjectGeneral' },
  { value: 'sales', labelKey: 'subjectSales' },
  { value: 'support', labelKey: 'subjectSupport' },
  { value: 'partnerships', labelKey: 'subjectPartnerships' },
] as const;

export default function ContactForm() {
  const t = useTranslations('Contact');
  const [state, formAction, isPending] = useActionState(
    async (_: { success: boolean; error: string | null }, formData: FormData) => {
      const result = await submitContact(formData);
      return result.success
        ? { success: true, error: null }
        : { success: false, error: result.error };
    },
    { success: false, error: null as string | null }
  );

  return (
    <form action={formAction} className="space-y-6">
      <div className="grid gap-5 md:grid-cols-2">
        <div className="space-y-2">
          <label className="flex items-center gap-2 text-label" htmlFor="contact-fullName">
            <User className="h-3.5 w-3.5" />
            {t('fullName')}
          </label>
          <input
            id="contact-fullName"
            type="text"
            name="fullName"
            required
            placeholder={t('fullNamePlaceholder')}
            className="input input-bordered w-full min-h-11"
          />
        </div>
        <div className="space-y-2">
          <label className="flex items-center gap-2 text-label" htmlFor="contact-email">
            <Mail className="h-3.5 w-3.5" />
            {t('emailAddress')}
          </label>
          <input
            id="contact-email"
            type="email"
            name="email"
            required
            placeholder={t('emailPlaceholder')}
            className="input input-bordered w-full min-h-11"
          />
        </div>
      </div>

      <div className="space-y-2">
        <label className="flex items-center gap-2 text-label" htmlFor="contact-subject">
          <Tag className="h-3.5 w-3.5" />
          {t('subject')}
        </label>
        <select
          id="contact-subject"
          name="subject"
          className="select select-bordered w-full min-h-11"
          defaultValue="general"
        >
          {SUBJECT_OPTIONS.map((opt) => (
            <option key={opt.value} value={opt.value}>
              {t(opt.labelKey)}
            </option>
          ))}
        </select>
      </div>

      <div className="space-y-2">
        <label className="flex items-center gap-2 text-label" htmlFor="contact-message">
          <MessageSquare className="h-3.5 w-3.5" />
          {t('message')}
        </label>
        <textarea
          id="contact-message"
          name="message"
          rows={6}
          required
          placeholder={t('messagePlaceholder')}
          className="textarea textarea-bordered w-full min-h-32"
        />
      </div>

      {state.success && (
        <div className="flex items-center gap-2 rounded-lg bg-success/15 text-success px-4 py-3" role="alert">
          <CheckCircle2 className="h-5 w-5 shrink-0" />
          <p className="text-sm font-medium">{t('successMessage')}</p>
        </div>
      )}
      {state.error && (
        <div className="flex items-center gap-2 rounded-lg bg-error/15 text-error px-4 py-3" role="alert">
          <AlertCircle className="h-5 w-5 shrink-0" />
          <p className="text-sm font-medium">{state.error}</p>
        </div>
      )}

      <button
        type="submit"
        className="btn btn-primary w-full gap-2 min-h-12 text-xs font-bold uppercase tracking-widest"
        disabled={isPending}
      >
        {isPending ? (
          <span className="loading loading-spinner loading-sm" />
        ) : (
          <>
            {t('sendMessage')}
            <Send className="h-4 w-4" />
          </>
        )}
      </button>
    </form>
  );
}
