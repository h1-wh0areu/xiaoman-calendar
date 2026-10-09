export interface ClipboardParseResult {
  title?: string;
  startHint?: string;
  location?: string;
  people?: string[];
  confidence: number;
  uncertainFields: string[];
}

const LOC_RE = /(会议室[A-Za-z0-9]?|腾讯会议|Zoom|[\u4e00-\u9fa5]{0,6}考场|医院|[\u4e00-\u9fa5]{2,8}(大厦|中心|酒店|机场))/;
const PEOPLE_RE = /与?([\u4e00-\u9fa5]{2,4})(老师|经理|总|同学)/;

function extractStartHint(text: string): string | undefined {
  const withTime = text.match(
    /(\d{1,2})月(\d{1,2})[日号]\s*(上午|下午|晚上)?\s*(\d{1,2})[点时:：](\d{0,2})/,
  );
  if (withTime) {
    let h = Number(withTime[4]);
    const min = withTime[5] ? Number(withTime[5]) : 0;
    if (withTime[3] === '下午' || withTime[3] === '晚上') h = h < 12 ? h + 12 : h;
    if (withTime[3] === '上午' && h === 12) h = 0;
    return `${withTime[1]!.padStart(2, '0')}-${withTime[2]!.padStart(2, '0')} ${String(h).padStart(2, '0')}:${String(min).padStart(2, '0')}`;
  }

  const dateOnly = text.match(/(\d{1,2})月(\d{1,2})[日号]/);
  if (dateOnly) {
    return `${dateOnly[1]!.padStart(2, '0')}-${dateOnly[2]!.padStart(2, '0')}`;
  }

  const nextWeek = text.match(/下周([一二三四五六日天])\s*(上午|下午|晚上)?\s*(\d{1,2})[点时:：]?(\d{0,2})?/);
  if (nextWeek) {
    return `下周${nextWeek[1]} ${nextWeek[2] ?? ''}${nextWeek[3]}:${nextWeek[4] || '00'}`.trim();
  }

  const iso = text.match(/(\d{4})[-\/.](\d{1,2})[-\/.](\d{1,2})\s+(\d{1,2}):(\d{2})/);
  if (iso) {
    return `${iso[1]}-${iso[2]!.padStart(2, '0')}-${iso[3]!.padStart(2, '0')} ${iso[4]!.padStart(2, '0')}:${iso[5]}`;
  }

  return undefined;
}

/**
 * Local-only parse. Caller must discard original clipboard text after use.
 */
export function parseClipboard(text: string): ClipboardParseResult | null {
  const trimmed = text.trim();
  if (!trimmed || trimmed.length < 4) return null;

  const uncertain: string[] = [];
  const startHint = extractStartHint(trimmed);
  if (!startHint) uncertain.push('start');

  const loc = trimmed.match(LOC_RE)?.[0];
  if (!loc) uncertain.push('location');

  const people: string[] = [];
  const pm = trimmed.match(PEOPLE_RE);
  if (pm) people.push(`${pm[1]}${pm[2] ?? ''}`);
  else uncertain.push('people');

  let title = trimmed
    .replace(/(\d{1,2})月(\d{1,2})[日号]\s*(上午|下午|晚上)?\s*(\d{1,2})[点时:：](\d{0,2})?/, '')
    .replace(/(\d{1,2})月(\d{1,2})[日号]/, '')
    .replace(/下周([一二三四五六日天])\s*(上午|下午|晚上)?\s*(\d{1,2})[点时:：]?(\d{0,2})?/, '')
    .replace(LOC_RE, '')
    .replace(/[，,。\s]+/g, ' ')
    .trim();
  if (!title || title.length < 2) {
    title = trimmed.slice(0, 24);
    uncertain.push('title');
  }

  const confidence =
    0.4 + (startHint ? 0.35 : 0) + (loc ? 0.15 : 0) + (people.length ? 0.1 : 0);

  if (confidence < 0.45) return null;

  return {
    title,
    startHint,
    location: loc,
    people,
    confidence: Math.min(0.99, confidence),
    uncertainFields: uncertain,
  };
}
