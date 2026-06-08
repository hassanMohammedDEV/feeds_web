const SUPABASE_URL = 'https://qcextisarugocgpfpzms.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFjZXh0aXNhcnVnb2NncGZwem1zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA4Njk3MjMsImV4cCI6MjA5NjQ0NTcyM30.cJi0eFU96deQdl7bAk1OvXZW_EjTbsOQrIGxvVQBO7I';

async function supabaseRPC(functionName, params = {}) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${functionName}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'apikey': SUPABASE_ANON_KEY,
      'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
    },
    body: JSON.stringify(params),
  });
  return await res.json();
}
