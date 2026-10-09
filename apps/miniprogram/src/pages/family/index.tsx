import { View, Text, Button } from '@tarojs/components';
import { useLoad } from '@tarojs/taro';
import { useState } from 'react';
import { apiGet, apiPost } from '../../utils/api';

export default function FamilyPage() {
  const [fam, setFam] = useState<any>(null);

  const load = async () => {
    const list = await apiGet<any[]>('/families');
    setFam(list[0]);
  };

  useLoad(load);

  if (!fam) return <View style={{ padding: 20 }}>加载中…</View>;

  return (
    <View style={{ padding: 20 }}>
      <Text style={{ fontSize: 22, fontWeight: 700 }}>{fam.name}</Text>
      {fam.claims?.map((c: any) => (
        <View key={c.id} style={{ marginTop: 12 }}>
          <Text>
            {c.title} · {c.claimant || '待认领'}
          </Text>
          {!c.claimant && (
            <Button
              size="mini"
              onClick={async () => {
                await apiPost(`/families/${fam.id}/claims/${c.id}/claim`, { name: '我' });
                load();
              }}
            >
              认领
            </Button>
          )}
        </View>
      ))}
      <Button
        style={{ marginTop: 20 }}
        onClick={async () => {
          await apiPost('/med-reminders/med-dad/confirm');
        }}
      >
        服药确认（电话按1 Mock）
      </Button>
    </View>
  );
}
