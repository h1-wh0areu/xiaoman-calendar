import Taro from '@tarojs/taro';

const BASE = 'http://127.0.0.1:3000/v1';

let token = '';

export async function ensureLogin() {
  if (token) return token;
  await Taro.request({ url: `${BASE}/auth/sms/send`, method: 'POST', data: { phone: '13800138000' } });
  const res = await Taro.request({
    url: `${BASE}/auth/sms/verify`,
    method: 'POST',
    data: { phone: '13800138000', code: '000000' },
  });
  token = (res.data as { accessToken: string }).accessToken;
  return token;
}

export async function apiGet<T = unknown>(path: string): Promise<T> {
  await ensureLogin();
  const res = await Taro.request({
    url: `${BASE}${path}`,
    header: { Authorization: `Bearer ${token}` },
  });
  return res.data as T;
}

export async function apiPost<T = unknown>(path: string, data?: unknown): Promise<T> {
  await ensureLogin();
  const res = await Taro.request({
    url: `${BASE}${path}`,
    method: 'POST',
    data,
    header: { Authorization: `Bearer ${token}` },
  });
  return res.data as T;
}
