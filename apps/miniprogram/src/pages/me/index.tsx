import { View, Text, Button } from '@tarojs/components';
import Taro, { useLoad } from '@tarojs/taro';
import { useState } from 'react';
import { apiGet, apiPost } from '../../utils/api';

export default function MePage() {
  const [me, setMe] = useState<any>(null);
  useLoad(async () => setMe(await apiGet('/me')));

  return (
    <View style={{ padding: 20 }}>
      <Text style={{ fontSize: 22, fontWeight: 700 }}>我的</Text>
      <Text style={{ display: 'block', marginTop: 8, color: '#8a8a8a' }}>
        {me?.displayName} · {me?.phone}
      </Text>
      <Button style={{ marginTop: 16 }} onClick={() => Taro.navigateTo({ url: '/pages/clipboard/index' })}>
        粘贴建日程
      </Button>
      <Button
        style={{ marginTop: 8 }}
        onClick={async () => {
          await apiPost('/me/export');
          Taro.showToast({ title: '已导出', icon: 'success' });
        }}
      >
        导出数据
      </Button>
    </View>
  );
}
