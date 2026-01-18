/**
 * Browser-side Supabase Client
 *
 * This client is used for client-side operations in the browser.
 * It's created fresh on each page load and uses the anon key for authentication.
 *
 * Usage in client components:
 * ```typescript
 * import { createClient } from '@/lib/supabase/client'
 *
 * const supabase = createClient()
 * const { data } = await supabase.from('invoices').select()
 * ```
 *
 * NOTE: This client requires @supabase/supabase-js to be installed:
 * npm install @supabase/supabase-js
 */

import { createBrowserClient } from '@supabase/ssr';
import { Database } from './types';

/**
 * Creates a Supabase client for browser-side operations
 *
 * This client:
 * - Uses the anon (public) key for initial authentication
 * - Uses browser storage (localStorage) for session persistence
 * - Should be used for client-side queries, real-time subscriptions, etc.
 * - Cannot perform admin operations (use server client for that)
 *
 * @returns A configured Supabase client instance
 */
export const createClient = () => {
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  if (!supabaseUrl || !supabaseAnonKey) {
    throw new Error(
      'Missing Supabase environment variables. ' +
      'Please set NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY'
    );
  }

  return createBrowserClient<Database>(supabaseUrl, supabaseAnonKey);
};

/**
 * Export type for the Supabase client instance
 * Useful for type annotations in your components
 */
export type SupabaseClient = ReturnType<typeof createClient>;
