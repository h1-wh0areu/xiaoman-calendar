import { View, Text, Button, Textarea } from '@tarojs/components';
import Taro, { useLoad, useRouter } from '@tarojs/taro';
import { useState } from 'react';
import { apiGet, apiPost } from '../../utils/api';

export default function SignOffPage() {
  const router = useRouter();
  const [conflict, setConflict] = useState<any>(null);
  const [ticket, setTicket] = useState<any>(null);
  const [note, setNote] = useState('');

  useLoad(async () => {
    const id = router.params.conflictId || 'c-today';
    setConflict(await apiGet(`/conflicts/${id}`));
  });

  const choose = async (optionId: string) => {
    const res = await apiPost<any>(`/conflicts/${conflict.id}/choose`, { optionId });
    if (res.needsSignOff) setTicket(res.ticket);
    else Taro.showToast({ title: '已执行', icon: 'success' });
  };

  const approve = async () => {
    await apiPost(`/sign-off/${ticket.id}/approve`, { handwrittenNote: note });
    Taro.showToast({ title: '已签发', icon: 'success' });
  };

  if (!conflict) return <View style={{ padding: 20 }}>加载中…</View>;

  return (
    <View style={{ padding: 20 }}>
      <Text style={{ fontSize: 20, fontWeight: 700 }}>冲突仲裁 / 签发</Text>
      <Text style={{ display: 'block', margin: '10px 0' }}>{conflict.label}</Text>
      {!ticket &&
        conflict.options?.map((o: any) => (
          <Button key={o.id} style={{ marginBottom: 8 }} onClick={() => choose(o.id)}>
            {o.lean}
          </Button>
        ))}
      {ticket && (
        <View>
          <Text style={{ display: 'block', marginBottom: 8 }}>{ticket.content}</Text>
          <Textarea value={note} onInput={(e) => setNote(e.detail.value)} placeholder="手写补充区" />
          <Button type="primary" onClick={approve}>
            一键签发
          </Button>
        </View>
      )}
    </View>
  );
}
