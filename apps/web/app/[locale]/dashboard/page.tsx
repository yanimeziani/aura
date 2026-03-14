import { redirect } from 'next/navigation';
import { useLocale } from 'next-intl';

export default function DashboardRedirect() {
  const locale = useLocale();
  redirect(`/${locale}/sovereign`);
}
