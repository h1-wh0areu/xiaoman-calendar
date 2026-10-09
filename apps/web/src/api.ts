const BASE = '/v1';
let token = '';

export async function login(phone = '13800138000') {
  await fetch(`${BASE}/auth/sms/send`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ phone }),
  });
  const res = await fetch(`${BASE}/auth/sms/verify`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ phone, code: '000000' }),
  });
  const data = await res.json();
  token = data.accessToken;
  return data;
}

async function headers() {
  if (!token) await login();
  return {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${token}`,
  };
}

export async function get<T>(path: string): Promise<T> {
  const res = await fetch(`${BASE}${path}`, { headers: await headers() });
  return res.json();
}

export async function post<T>(path: string, body?: unknown): Promise<T> {
  const res = await fetch(`${BASE}${path}`, {
    method: 'POST',
    headers: await headers(),
    body: JSON.stringify(body ?? {}),
  });
  return res.json();
}
