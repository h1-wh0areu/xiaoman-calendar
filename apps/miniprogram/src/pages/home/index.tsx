import { View, Text } from '@tarojs/components';
import Taro, { useLoad } from '@tarojs/taro';
import { useState } from 'react';
import { apiGet } from '../../utils/api';
import './index.css';

export default function HomePage() {
  const [brief, setBrief] = useState<any>(null);

  useLoad(async () => {
    const data = await apiGet('/brief/morning?date=2026-10-09');
    setBrief(data);
  });

  if (!brief) return <View className="page">加载中…</View>;

  return (
    <View className="page">
      <Text className="title">{brief.title}</Text>
      <Text className="sub">{brief.subtitle}</Text>
      {brief.conflictBanner && (
        <View
          className="banner"
          onClick={() =>
            Taro.navigateTo({ url: `/pages/signoff/index?conflictId=${brief.conflictBanner.conflictId}` })
          }
        >
          <Text className="bannerTitle">⚠ {brief.conflictBanner.count} 个雷</Text>
          <Text>{brief.conflictBanner.summary} →</Text>
        </View>
      )}
      {brief.items?.map((item: any) => (
        <View key={item.event.id} className="row">
          <View className="bar" style={{ background: item.color }} />
          <Text className="time">
            {new Date(item.event.start).toTimeString().slice(0, 5)}
          </Text>
          <Text className="rowTitle">{item.event.title}</Text>
          <Text className={`badge ${item.badgeTone}`}>{item.badge}</Text>
        </View>
      ))}
      <Text className="closing">{brief.closing}</Text>
    </View>
  );
}
