import { View, Text, Textarea, Button } from '@tarojs/components';
import Taro from '@tarojs/taro';
import { useState } from 'react';
import { apiPost } from '../../utils/api';

export default function ClipboardPage() {
  const [text, setText] = useState('12月1日 科目二考试 西丽考场');
  const [draft, setDraft] = useState<any>(null);

  return (
    <View style={{ padding: 20 }}>
      <Text style={{ fontSize: 20, fontWeight: 700 }}>粘贴建日程</Text>
      <Textarea value={text} onInput={(e) => setText(e.detail.value)} style={{ marginTop: 12 }} />
      <Button
        onClick={async () => {
          const res = await apiPost<any>('/events/from-clipboard', { text });
          setDraft(res.draft);
        }}
      >
        识别
      </Button>
      {draft && (
        <View style={{ marginTop: 12 }}>
          <Text>
            {draft.title} / {draft.startHint} / {draft.location}
          </Text>
          <Button
            type="primary"
            onClick={async () => {
              await apiPost('/events', {
                title: draft.title,
                start: '2026-12-01T09:00:00+08:00',
                end: '2026-12-01T11:00:00+08:00',
                location: draft.location,
                domain: 'study',
              });
              Taro.showToast({ title: '已建档', icon: 'success' });
            }}
          >
            一键确认
          </Button>
        </View>
      )}
    </View>
  );
}
