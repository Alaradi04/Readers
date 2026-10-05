import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (request.method !== 'POST') {
    return Response.json({ error: 'Method not allowed.' }, { status: 405, headers: corsHeaders })
  }

  try {
    const { username, password } = await request.json()
    if (typeof username !== 'string' || !username.trim() || typeof password !== 'string') {
      return Response.json({ error: 'Enter a username and password.' }, { status: 400, headers: corsHeaders })
    }

    const url = Deno.env.get('SUPABASE_URL')!
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const adminClient = createClient(url, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    })
    const { data: profiles, error: lookupError } = await adminClient
      .from('profiles')
      .select('email')
      .eq('username', username.trim())
      .limit(2)

    if (lookupError || profiles?.length !== 1 || !profiles[0].email) {
      return Response.json({ error: 'Invalid username or password.' }, { headers: corsHeaders })
    }

    const authClient = createClient(url, anonKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    })
    const { data, error } = await authClient.auth.signInWithPassword({
      email: profiles[0].email,
      password,
    })

    if (error || !data.session) {
      return Response.json({ error: 'Invalid username or password.' }, { headers: corsHeaders })
    }

    return Response.json(
      { refresh_token: data.session.refresh_token },
      { headers: corsHeaders },
    )
  } catch {
    return Response.json({ error: 'Unable to sign in right now.' }, { status: 400, headers: corsHeaders })
  }
})