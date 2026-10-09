import { describe, expect, it } from 'vitest';
import { parseClipboard } from './clipboard-parser';

describe('parseClipboard', () => {
  it('parses natural language meeting', () => {
    const r = parseClipboard('下周三下午3点会议室A项目评审');
    expect(r).not.toBeNull();
    expect(r!.startHint).toContain('周三');
    expect(r!.location).toContain('会议室');
    expect(r!.confidence).toBeGreaterThan(0.5);
  });

  it('parses dated exam', () => {
    const r = parseClipboard('12月1日 科目二考试 西丽考场');
    expect(r).not.toBeNull();
    expect(r!.startHint).toMatch(/12-01/);
    expect(r!.location).toContain('考场');
  });

  it('returns null for junk', () => {
    expect(parseClipboard('ok')).toBeNull();
  });
});
