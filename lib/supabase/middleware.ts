import { createServerClient } from '@supabase/ssr';
import { NextResponse, type NextRequest } from 'next/server';

export async function updateSession(request: NextRequest) {
  let supabaseResponse = NextResponse.next({
    request,
  });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
          supabaseResponse = NextResponse.next({
            request,
          });
          cookiesToSet.forEach(({ name, value, options }) =>
            supabaseResponse.cookies.set(name, value, options)
          );
        },
      },
    }
  );

  // IMPORTANT: Avoid writing any logic between createServerClient and
  // supabase.auth.getUser(). A simple mistake can make it very hard to debug
  // issues with users being logged out randomly.

  const {
    data: { user },
  } = await supabase.auth.getUser();

  const path = request.nextUrl.pathname;
  const localePrefix = path.split('/')[1];
  const withLocale = (target: string) => (localePrefix ? `/${localePrefix}${target}` : target);

  if (
    !user &&
    !path.includes('/login') &&
    !path.includes('/auth') &&
    path.includes('/dashboard')
  ) {
    const url = request.nextUrl.clone();
    url.pathname = withLocale('/login');
    return NextResponse.redirect(url);
  }

  if (!user && path.includes('/onboarding')) {
    const url = request.nextUrl.clone();
    url.pathname = withLocale('/login');
    return NextResponse.redirect(url);
  }

  if (user && path.includes('/dashboard')) {
    const { data: merchant } = await supabase
      .from('merchants')
      .select('onboarding_complete, onboarding_completed')
      .eq('id', user.id)
      .single();

    const onboardingDone = merchant?.onboarding_completed ?? merchant?.onboarding_complete ?? false;
    if (!onboardingDone) {
      const url = request.nextUrl.clone();
      url.pathname = withLocale('/onboarding/profile');
      return NextResponse.redirect(url);
    }
  }

  // IMPORTANT: You *must* return the supabaseResponse object as is. If you're creating a
  // new response object with NextResponse.next() make sure to:
  // 1. Pass the request in it, like so:
  //    const myNewResponse = NextResponse.next({ request })
  // 2. Copy over the cookies, like so:
  //    myNewResponse.cookies.setAll(supabaseResponse.cookies.getAll())
  // 3. Change the myNewResponse object to fit your needs, but avoid changing
  //    the cookies!
  // 4. Return the myNewResponse object.

  return supabaseResponse;
}
