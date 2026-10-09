import { View, Text } from '@tarojs/components';
import { useLoad } from '@tarojs/taro';
import { useState } from 'react';
import { apiGet } from '../../utils/api';

export default function TimelinePage() {
  const [items, setItems] = useState<any[]>([]);
  const [insight, setInsight] = useState('');

  useLoad(async () => {
    const data = await apiGet<any>('/timeline?months=1');
    setItems(data.items || []);
    setInsight(data.insight || '');
  });

  return (
    <View style={{ padding: 20 }}>
      <Text style={{ fontSize: 22, fontWeight: 700 }}>时间线 · 1个月</Text>
      {insight ? <Text style={{ color: '#f59a23', display: 'block', marginTop: 10 }}>{insight}</Text> : null}
      {items.map((e) => (
        <View key={e.id} style={{ padding: '10px 0', display: 'flex' }}>
          <Text>
            {new Date(e.start).getMonth() + 1}.{new Date(e.start).getDate()} {e.title}
          </Text>
        </View>
      ))}
    </View>
  );
}
