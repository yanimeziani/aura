'use client';

import { useEffect, useState, useMemo } from 'react';
import { useTranslations } from 'next-intl';
import { Link } from '@/i18n/navigation';
import {
  ChevronLeft,
  RefreshCw,
  BarChart3,
  MessageSquare,
  Clock,
  TrendingUp,
  User,
  Bot,
  ChevronDown,
  ChevronUp,
} from 'lucide-react';

interface Message {
  id: string;
  role: string;
  message: string;
  created_at: string;
}

interface DebtorSummary {
  status: string;
  currency: string;
  total_debt: number;
  last_contacted: string | null;
  recoveryScore: number;
}

interface Props {
  debtorId: string;
  debtorName: string;
  debtorSummary: DebtorSummary;
  initialMessages: Message[];
  locale: string;
}

export default function SpectatorChat({
  debtorId,
  debtorName,
  debtorSummary,
  initialMessages,
  locale,
}: Props) {
  const t = useTranslations('Dashboard');
  const [messages, setMessages] = useState<Message[]>(initialMessages);
  const [autoRefresh, setAutoRefresh] = useState(true);
  const [showAnalytics, setShowAnalytics] = useState(true);
  const [compactView, setCompactView] = useState(false);

  const fetchMessages = () => {
    fetch(`/api/conversations/${debtorId}`)
      .then((res) => (res.ok ? res.json() : null))
      .then((data) => {
        if (data?.messages?.length !== undefined) setMessages(data.messages);
      })
      .catch(() => {});
  };

  useEffect(() => {
    if (!autoRefresh) return;
    const interval = setInterval(fetchMessages, 5000);
    return () => clearInterval(interval);
  }, [debtorId, autoRefresh]);

  const stats = useMemo(() => {
    const user = messages.filter((m) => m.role === 'user');
    const assistant = messages.filter((m) => m.role === 'assistant');
    const firstAt = messages.length ? new Date(messages[0].created_at) : null;
    const lastAt = messages.length ? new Date(messages[messages.length - 1].created_at) : null;
    let avgResponseMs: number | null = null;
    if (user.length > 0 && assistant.length > 0) {
      const pairs: number[] = [];
      for (let i = 0; i < messages.length - 1; i++) {
        if (messages[i].role === 'user' && messages[i + 1].role === 'assistant') {
          pairs.push(
            new Date(messages[i + 1].created_at).getTime() - new Date(messages[i].created_at).getTime(),
          );
        }
      }
      if (pairs.length) {
        avgResponseMs = Math.round(pairs.reduce((a, b) => a + b, 0) / pairs.length);
      }
    }
    return {
      userCount: user.length,
      assistantCount: assistant.length,
      firstAt,
      lastAt,
      avgResponseMs,
    };
  }, [messages]);

  const statusLabel = (s: string) => {
    const map: Record<string, string> = {
      contacted: t('statusContacted'),
      promise_to_pay: t('statusPromise'),
      no_answer: t('statusNoAnswer'),
      escalated: t('statusEscalated'),
      paid: t('statusPaid'),
    };
    return map[s] ?? t('statusPending');
  };

  return (
    <div className="flex flex-col lg:flex-row gap-4 h-[calc(100dvh-6rem)]">
      {/* Main chat + HUD */}
      <div className="flex flex-col flex-1 min-h-0 border border-base-300/50 rounded-2xl bg-base-200/30 overflow-hidden shadow-warm">
        {/* HUD control bar */}
        <div className="flex items-center gap-2 px-4 py-2.5 border-b border-base-300/50 bg-base-100/95 shrink-0 flex-wrap">
          <Link
            href={`/${locale}/dashboard`}
            className="btn btn-ghost btn-sm btn-square"
            aria-label={t('backToDashboard')}
          >
            <ChevronLeft className="h-5 w-5" />
          </Link>
          <div className="flex-1 min-w-0">
            <h1 className="font-bold text-sm truncate">{debtorName}</h1>
            <p className="text-[10px] text-base-content/50">{t('spectatorView')}</p>
          </div>
          <div className="flex items-center gap-1">
            <button
              type="button"
              onClick={fetchMessages}
              className="btn btn-ghost btn-sm btn-square"
              title={t('refresh')}
              aria-label={t('refresh')}
            >
              <RefreshCw className="h-4 w-4" />
            </button>
            <label className="flex items-center gap-1.5 cursor-pointer">
              <input
                type="checkbox"
                className="toggle toggle-xs"
                checked={autoRefresh}
                onChange={(e) => setAutoRefresh(e.target.checked)}
              />
              <span className="text-[10px] text-base-content/60">{t('autoRefresh')}</span>
            </label>
            <button
              type="button"
              onClick={() => setCompactView((v) => !v)}
              className="btn btn-ghost btn-sm"
              title={compactView ? t('viewFull') : t('viewCompact')}
            >
              <MessageSquare className="h-4 w-4" />
              <span className="text-[10px] hidden sm:inline">{compactView ? t('viewFull') : t('viewCompact')}</span>
            </button>
            <button
              type="button"
              onClick={() => setShowAnalytics((v) => !v)}
              className={`btn btn-sm gap-1 ${showAnalytics ? 'btn-primary btn-outline' : 'btn-ghost'}`}
            >
              <BarChart3 className="h-4 w-4" />
              <span className="text-xs hidden sm:inline">{t('analytics')}</span>
              {showAnalytics ? <ChevronUp className="h-3 w-3" /> : <ChevronDown className="h-3 w-3" />}
            </button>
          </div>
        </div>

        {/* Chat area */}
        <main className="flex-1 overflow-y-auto p-4 space-y-4 min-h-0">
          {messages.length === 0 ? (
            <p className="text-sm text-base-content/50 text-center py-8">{t('noMessagesYet')}</p>
          ) : (
            messages.map((m) => (
              <div
                key={m.id}
                className={`chat ${m.role === 'user' ? 'chat-end' : 'chat-start'}`}
              >
                <div
                  className={`chat-bubble text-sm leading-relaxed max-w-[85%] ${
                    compactView ? 'py-1.5 px-3' : ''
                  } ${
                    m.role === 'user'
                      ? 'chat-bubble-primary'
                      : 'bg-base-100 border border-base-300/40 text-base-content'
                  }`}
                >
                  {m.message}
                </div>
                {!compactView && (
                  <div className="chat-footer opacity-50 text-[10px] mt-0.5">
                    {m.role === 'user' ? debtorName : t('dragunAgent')} · {new Date(m.created_at).toLocaleString()}
                  </div>
                )}
              </div>
            ))
          )}
        </main>

        <footer className="px-4 py-2 border-t border-base-300/30 bg-base-100/80 text-[10px] text-base-content/50 text-center shrink-0">
          {t('spectatorFooter')}
        </footer>
      </div>

      {/* Analytics panel */}
      {showAnalytics && (
        <aside className="w-full lg:w-72 shrink-0 flex flex-col gap-3">
          <div className="rounded-2xl border border-base-300/50 bg-base-200/50 p-4 shadow-warm space-y-4">
            <h2 className="text-xs font-bold uppercase tracking-wider text-base-content/60 flex items-center gap-2">
              <BarChart3 className="h-3.5 w-3.5" />
              {t('analytics')}
            </h2>

            <div className="grid grid-cols-2 gap-3">
              <div className="rounded-lg bg-base-100/80 p-3 border border-base-300/30">
                <p className="text-[10px] text-base-content/50 uppercase tracking-wider">{t('accountStatus')}</p>
                <p className="text-sm font-semibold mt-0.5">{statusLabel(debtorSummary.status)}</p>
              </div>
              <div className="rounded-lg bg-base-100/80 p-3 border border-base-300/30">
                <p className="text-[10px] text-base-content/50 uppercase tracking-wider">{t('exposure')}</p>
                <p className="text-sm font-semibold mt-0.5 tabular-nums">
                  {debtorSummary.currency} {debtorSummary.total_debt.toLocaleString()}
                </p>
              </div>
              <div className="rounded-lg bg-base-100/80 p-3 border border-base-300/30">
                <p className="text-[10px] text-base-content/50 uppercase tracking-wider">{t('recoveryScore')}</p>
                <p className="text-sm font-semibold mt-0.5 flex items-center gap-1">
                  <TrendingUp className="h-3.5 w-3.5 text-primary" />
                  {debtorSummary.recoveryScore}
                </p>
              </div>
              <div className="rounded-lg bg-base-100/80 p-3 border border-base-300/30">
                <p className="text-[10px] text-base-content/50 uppercase tracking-wider">{t('lastContacted')}</p>
                <p className="text-sm font-medium mt-0.5 truncate">
                  {debtorSummary.last_contacted
                    ? new Date(debtorSummary.last_contacted).toLocaleString()
                    : '—'}
                </p>
              </div>
            </div>

            <div className="border-t border-base-300/30 pt-3 space-y-2">
              <p className="text-[10px] text-base-content/50 uppercase tracking-wider">{t('conversationStats')}</p>
              <div className="flex items-center gap-4 text-sm">
                <span className="flex items-center gap-1.5">
                  <User className="h-3.5 w-3.5 text-primary" />
                  {stats.userCount} {t('debtorMessages')}
                </span>
                <span className="flex items-center gap-1.5">
                  <Bot className="h-3.5 w-3.5 text-base-content/60" />
                  {stats.assistantCount} {t('agentReplies')}
                </span>
              </div>
              {stats.firstAt && (
                <div className="flex items-center gap-1.5 text-[11px] text-base-content/60">
                  <Clock className="h-3 w-3" />
                  {t('firstActivity')}: {stats.firstAt.toLocaleString()}
                </div>
              )}
              {stats.lastAt && (
                <div className="flex items-center gap-1.5 text-[11px] text-base-content/60">
                  <Clock className="h-3 w-3" />
                  {t('lastActivity')}: {stats.lastAt.toLocaleString()}
                </div>
              )}
              {stats.avgResponseMs != null && stats.avgResponseMs > 0 && (
                <div className="text-[11px] text-base-content/60">
                  {t('avgResponseTime')}: {stats.avgResponseMs < 1000 ? `${stats.avgResponseMs}ms` : `${(stats.avgResponseMs / 1000).toFixed(1)}s`}
                </div>
              )}
            </div>
          </div>
        </aside>
      )}
    </div>
  );
}
