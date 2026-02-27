import { Link } from '@/i18n/navigation';
import { ArrowLeft } from 'lucide-react';
import Logo from '@/components/Logo';

export default function NotFound() {
  return (
    <div className="min-h-screen bg-base-100 flex items-center justify-center p-6">
      <div className="text-center max-w-md space-y-6">
        <Logo className="h-8 w-auto mx-auto" />
        <div className="space-y-2">
          <p className="text-6xl font-bold tracking-tight text-base-content/20">404</p>
          <h1 className="text-xl font-bold">Page not found</h1>
          <p className="text-sm text-base-content/50">
            The page you're looking for doesn't exist or has been moved.
          </p>
        </div>
        <Link href="/" className="btn btn-primary gap-2">
          <ArrowLeft className="h-4 w-4" />
          Back to home
        </Link>
      </div>
    </div>
  );
}
