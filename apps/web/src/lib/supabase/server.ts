/**
 * Server-side Supabase Client
 *
 * This client is used for server-side operations in Next.js 14 App Router.
 * It handles authentication via cookies and has access to the service role key
 * for admin operations.
 *
 * Usage in Server Components:
 * ```typescript
 * import { createServerClient } from '@/lib/supabase/server'
 *
 * const supabase = await createServerClient()
 * const { data } = await supabase.from('invoices').select()
 * ```
 *
 * Usage in API Routes:
 * ```typescript
 * import { createServerClient } from '@/lib/supabase/server'
 * import { cookies } from 'next/headers'
 *
 * export async function GET(request: Request) {
 *   const supabase = await createServerClient()
 *   const { data } = await supabase.from('invoices').select()
 *   return Response.json(data)
 * }
 * ```
 *
 * Usage in Middleware:
 * ```typescript
 * import { createServerClient } from '@/lib/supabase/server'
 * import { cookies } from 'next/headers'
 *
 * export async function middleware(request: NextRequest) {
 *   let response = NextResponse.next({ request })
 *   const supabase = await createServerClient()
 *   // Use supabase for auth checks, etc.
 *   return response
 * }
 * ```
 *
 * NOTE: This client requires @supabase/ssr to be installed:
 * npm install @supabase/ssr
 */

import { createServerClient, type CookieOptions } from '@supabase/ssr';
import { cookies } from 'next/headers';
import { Database } from './types';

/**
 * Creates a Supabase client for server-side operations
 *
 * This client:
 * - Uses cookies for session management (persistent auth)
 * - Requires Next.js cookies() API (only works in App Router)
 * - Can be used in Server Components, Route Handlers, Middleware, etc.
 * - Handles automatic refresh of expired tokens
 * - Maintains user session across requests
 *
 * @returns A promise that resolves to a configured Supabase client instance
 *
 * @example
 * // In a Server Component
 * const supabase = await createServerClient();
 * const { data: { user } } = await supabase.auth.getUser();
 *
 * @example
 * // In a Route Handler
 * export async function POST(request: Request) {
 *   const supabase = await createServerClient();
 *   const { data, error } = await supabase.from('invoices').insert([...]);
 *   return Response.json({ data, error });
 * }
 */
export const createServerClient = async () => {
  const cookieStore = await cookies();

  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  if (!supabaseUrl || !supabaseAnonKey) {
    throw new Error(
      'Missing Supabase environment variables. ' +
      'Please set NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY'
    );
  }

  return createServerClient<Database>(supabaseUrl, supabaseAnonKey, {
    cookies: {
      /**
       * Get a cookie by name
       * The cookie store is used to read auth session cookies
       */
      getAll() {
        return cookieStore.getAll();
      },

      /**
       * Set a cookie with specific options
       * This is called when Supabase updates the auth session
       */
      setAll(cookiesToSet) {
        try {
          cookiesToSet.forEach(({ name, value, options }) => {
            cookieStore.set(name, value, options);
          });
        } catch (error) {
          // The `setAll` method was called from a Server Component.
          // This can be ignored if you have middleware refreshing
          // user sessions.
        }
      },
    },
  });
};

/**
 * Get the currently authenticated user
 *
 * This is a helper function that gets the current user session
 * and returns the user object if authenticated.
 *
 * @returns The authenticated user object or null if not authenticated
 *
 * @example
 * const user = await getCurrentUser();
 * if (!user) {
 *   redirect('/login');
 * }
 */
export const getCurrentUser = async () => {
  try {
    const supabase = await createServerClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    return user;
  } catch (error) {
    console.error('Error getting current user:', error);
    return null;
  }
};

/**
 * Get the current user's session
 *
 * Returns the full session object including access and refresh tokens.
 * Useful for getting token information for external API calls.
 *
 * @returns The session object or null if not authenticated
 *
 * @example
 * const session = await getSession();
 * const accessToken = session?.access_token;
 */
export const getSession = async () => {
  try {
    const supabase = await createServerClient();
    const {
      data: { session },
    } = await supabase.auth.getSession();
    return session;
  } catch (error) {
    console.error('Error getting session:', error);
    return null;
  }
};

/**
 * Sign out the current user
 *
 * Clears the session cookies and signs the user out.
 *
 * @example
 * await signOut();
 * redirect('/login');
 */
export const signOut = async () => {
  try {
    const supabase = await createServerClient();
    await supabase.auth.signOut();
  } catch (error) {
    console.error('Error signing out:', error);
    throw error;
  }
};

/**
 * Refresh the user's session
 *
 * This is useful when you want to ensure the user has a fresh token.
 * Normally this happens automatically, but you can call it manually
 * if needed.
 *
 * @example
 * const session = await refreshSession();
 */
export const refreshSession = async () => {
  try {
    const supabase = await createServerClient();
    const {
      data: { session },
    } = await supabase.auth.refreshSession();
    return session;
  } catch (error) {
    console.error('Error refreshing session:', error);
    return null;
  }
};

/**
 * Export type for the Supabase server client instance
 * Useful for type annotations
 */
export type SupabaseServerClient = Awaited<ReturnType<typeof createServerClient>>;
