import createMiddleware from 'next-intl/middleware';
import { routing } from './i18n/routing';
import { type NextRequest } from 'next/server';
import { updateSession } from '@/lib/supabase/middleware';
import arcjet, { detectBot, shield } from '@arcjet/next';

const intlMiddleware = createMiddleware(routing);

const arcjetKey = process.env.ARCJET_KEY;
const aj = arcjetKey
  ? arcjet({
      key: arcjetKey,
      rules: [
        shield({ mode: 'LIVE' }),
        detectBot({ mode: 'LIVE', allow: ['CATEGORY:SEARCH_ENGINE'] }),
      ],
    })
  : null;

const PROTECTED_PREFIXES = ['/dashboard', '/chat', '/pay', '/onboarding'];

function normalizePath(pathname: string) {
  return pathname.replace(/^\/(en|fr)(?=\/|$)/, '') || '/';
}

function isProtectedPath(pathname: string) {
  const normalized = normalizePath(pathname);
  return PROTECTED_PREFIXES.some((prefix) => normalized === prefix || normalized.startsWith(`${prefix}/`));
}

export default async function proxy(request: NextRequest) {
  if (aj && isProtectedPath(request.nextUrl.pathname)) {
    const decision = await aj.protect(request);
    if (decision.isDenied()) {
      return new Response(null, { status: 403 });
    }
  }

  // First update the supabase session
  const supabaseResponse = await updateSession(request);

  // If updateSession returns a redirect, return it immediately
  if (supabaseResponse.status === 307 || supabaseResponse.status === 302) {
    return supabaseResponse;
  }

  // Then run the i18n middleware
  // Note: we don't easily combine the responses here without more complex logic
  // but next-intl will generate its own response.
  // We should ideally pass the cookies from supabaseResponse to the final response.
  const response = await intlMiddleware(request);

  // Copy over cookies from supabaseResponse to the intl response
  supabaseResponse.cookies.getAll().forEach((cookie) => {
    response.cookies.set(cookie.name, cookie.value, {
      ...cookie,
    });
  });

  response.headers.set('X-Frame-Options', 'DENY');
  response.headers.set('X-Content-Type-Options', 'nosniff');
  response.headers.set('Referrer-Policy', 'strict-origin-when-cross-origin');
  response.headers.set('Permissions-Policy', 'camera=(), microphone=(), geolocation=()');

  return response;
}

export const config = {
  matcher: ['/((?!api|_next|.*\\..*).*)'],
};
