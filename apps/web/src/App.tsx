import { Link, Navigate, Route, Routes, useLocation, useNavigate, useParams } from 'react-router-dom';
import { useEffect, useState } from 'react';
import { get, post } from './api';

function Shell({ children }: { children: React.ReactNode }) {
  const loc = useLocation();
  const links = [
    ['/', '日程'],
    ['/timeline', '时间线'],
    ['/avatar', '分身'],
    ['/family', '家庭'],
    ['/me', '我的'],
  ];
  return (
    <div className="app">
      <aside className="rail">
        <div className="brand">小满</div>
        <div className="brand-sub">住在日程表里的第二个你</div>
        <nav className="nav">
          {links.map(([to, label]) => (
            <Link key={to} to={to} className={loc.pathname === to ? 'active' : ''}>
              {label}
            </Link>
          ))}
        </nav>
      </aside>
      <main className="main">{children}</main>
    </div>
  );
}

function Home() {
  const [brief, setBrief] = useState<any>(null);
  const nav = useNavigate();
  useEffect(() => {
    get('/brief/morning?date=2026-10-09').then(setBrief);
  }, []);
  if (!brief) return <p>加载中…</p>;
  return (
    <div className="phone-frame">
      <h1>{brief.title}</h1>
      <p className="muted">{brief.subtitle}</p>
      {brief.conflictBanner && (
        <div className="card warn" role="button" onClick={() => nav(`/conflicts/${brief.conflictBanner.conflictId}`)}>
          <strong style={{ color: 'var(--xm-conflict)' }}>⚠ {brief.conflictBanner.count} 个雷</strong>
          <div>{brief.conflictBanner.summary} →</div>
        </div>
      )}
      {brief.items?.map((item: any) => (
        <div
          className="row"
          key={item.event.id}
          onClick={() => {
            if (item.event.id === 'e-review') nav('/events/e-review/cheat-sheet');
            if (item.event.id === 'e-med') nav('/family/med/med-dad');
          }}
        >
          <div className="bar" style={{ background: item.color }} />
          <strong>{new Date(item.event.start).toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' })}</strong>
          <span>{item.event.title}</span>
          <span className={`badge ${item.badgeTone}`}>{item.badgeTone === 'ready' ? `✓${item.badge}` : item.badge}</span>
        </div>
      ))}
      <h3 style={{ marginTop: 24 }}>{brief.closing}</h3>
    </div>
  );
}

function Timeline() {
  const [months, setMonths] = useState(3);
  const [data, setData] = useState<any>(null);
  const nav = useNavigate();
  useEffect(() => {
    get(`/timeline?months=${months}`).then(setData);
  }, [months]);
  return (
    <div className="phone-frame">
      <h1>时间线 · 未来</h1>
      <div style={{ display: 'flex', gap: 8, margin: '12px 0' }}>
        {[1, 3, 6, 12].map((m) => (
          <button key={m} className={months === m ? '' : 'secondary'} onClick={() => setMonths(m)}>
            {m === 12 ? '1年' : `${m}月`}
          </button>
        ))}
      </div>
      {data?.insight && <p style={{ color: 'var(--xm-conflict)' }}>{data.insight}</p>}
      {data?.items?.map((e: any) => (
        <div
          className="row"
          key={e.id}
          onClick={() => {
            if (e.domain === 'document') nav(`/docs/${e.id === 'e-passport' ? 'doc-passport' : 'doc-license'}/alert`);
            if (e.id === 'e-mom-bday') nav('/life/birthday/bp-mom');
          }}
        >
          <div className="bar" style={{ background: `var(--xm-domain-${e.domain === 'document' ? 'document' : e.domain})` }} />
          <span>
            {new Date(e.start).getMonth() + 1}.{String(new Date(e.start).getDate()).padStart(2, '0')} {e.title}
          </span>
        </div>
      ))}
    </div>
  );
}

function CheatSheet() {
  const { id } = useParams();
  const [data, setData] = useState<any>(null);
  useEffect(() => {
    get(`/events/${id}/cheat-sheet`).then(setData);
  }, [id]);
  if (!data) return null;
  return (
    <div className="phone-frame">
      <h1>{data.title}</h1>
      <p className="muted">{data.event?.title} · {data.event?.location}</p>
      <div className="card">
        <strong>参会人物卡</strong>
        {data.people?.map((p: any) => (
          <div key={p.id} style={{ marginTop: 8 }}>
            {p.name}：{(p.traits || []).join(' · ')} {p.lastObjection || ''} {p.relationHint || ''}
          </div>
        ))}
      </div>
      {data.commitments?.[0] && (
        <div className="card warn">
          <strong style={{ color: 'var(--xm-conflict)' }}>待兑现承诺</strong>
          <div>上次评审你答应王总：{data.commitments[0].what} → 附草稿</div>
        </div>
      )}
      <div className="card">
        <strong style={{ color: 'var(--xm-primary)' }}>一句话策略</strong>
        <div>{data.strategy}</div>
      </div>
      <p className="muted">{data.dataNote}</p>
    </div>
  );
}

function Conflict() {
  const { id } = useParams();
  const nav = useNavigate();
  const [data, setData] = useState<any>(null);
  useEffect(() => {
    get(`/conflicts/${id}`).then(setData);
  }, [id]);
  if (!data) return null;
  return (
    <div className="phone-frame">
      <h1>冲突仲裁 · 需要你决定</h1>
      <div className="card danger">
        <strong style={{ color: 'var(--xm-danger)' }}>✕ {data.stage} 冲突</strong>
        <div>{data.label}</div>
      </div>
      {data.options?.map((o: any, idx: number) => (
        <div className="card" key={o.id}>
          <strong style={{ color: o.tone === 'primary' ? 'var(--xm-primary)' : 'var(--xm-success)' }}>
            方案{idx === 0 ? 'A' : 'B'} · {o.lean}
          </strong>
          <ul>{o.bullets?.map((b: string) => <li key={b}>{b}</li>)}</ul>
          {o.basis && <p className="muted">{o.basis}</p>}
          <button
            className={o.tone === 'primary' ? '' : 'secondary'}
            onClick={async () => {
              const res: any = await post(`/conflicts/${id}/choose`, { optionId: o.id });
              if (res.needsSignOff) nav(`/sign-off/${res.ticket.id}`);
              else alert('已选择方案B');
            }}
          >
            {o.needsSignOff ? '一键执行（需签发）' : '选择方案B'}
          </button>
        </div>
      ))}
      <p style={{ textAlign: 'center', fontWeight: 700 }}>建议权在AI，决定权在你。</p>
    </div>
  );
}

function SignOff() {
  const { id } = useParams();
  const [ticket, setTicket] = useState<any>(null);
  const [note, setNote] = useState('');
  const nav = useNavigate();
  useEffect(() => {
    get(`/sign-off/${id}`).then(setTicket);
  }, [id]);
  if (!ticket) return null;
  return (
    <div className="phone-frame">
      <h1>签发台</h1>
      <p className="muted">语气相似度 {ticket.toneScore}</p>
      <div className="card">{ticket.content}</div>
      <textarea
        value={note}
        onChange={(e) => setNote(e.target.value)}
        placeholder="手写补充区"
        style={{ width: '100%', minHeight: 80, marginBottom: 12 }}
      />
      <button
        onClick={async () => {
          await post(`/sign-off/${id}/approve`, { handwrittenNote: note });
          alert('已签发并执行');
          nav('/');
        }}
      >
        签发
      </button>
    </div>
  );
}

function Med() {
  const { id } = useParams();
  const [med, setMed] = useState<any>(null);
  const load = () => get<any[]>('/med-reminders').then((list) => setMed(list.find((m) => m.id === id) || list[0]));
  useEffect(() => {
    load();
  }, [id]);
  if (!med) return null;
  return (
    <div className="phone-frame">
      <h1>
        服药守护 · {med.elderName}
      </h1>
      <p className="muted">
        {med.drug} {med.dose} · {med.scheduleLabel}
      </p>
      <div className="card">三级触达：语音播报 → 电话外呼（子女录音）→ 通知子女</div>
      <p>状态：{med.confirmState}</p>
      <button onClick={async () => { await post(`/med-reminders/${med.id}/confirm`); load(); }}>模拟按1确认</button>
    </div>
  );
}

function Birthday() {
  const { id } = useParams();
  const [plan, setPlan] = useState<any>(null);
  useEffect(() => {
    get(`/birthday-plans/${id}`).then(setPlan);
  }, [id]);
  if (!plan) return null;
  return (
    <div className="phone-frame">
      <h1>
        {plan.personName} · {plan.dateLabel}
      </h1>
      <div className="card">
        <strong>祝福话术</strong>
        <p>{plan.script}</p>
      </div>
      <div className="card">
        <strong>礼物建议</strong>
        {plan.gifts?.map((g: any) => (
          <div key={g.tier}>
            【{g.tier}】{g.title} — {g.reason}
            {g.affiliate ? '（合作）' : ''}
          </div>
        ))}
      </div>
      <p className="muted">记忆依据：{(plan.memoryBasis || []).join(' · ')}</p>
    </div>
  );
}

function DocAlert() {
  const { id } = useParams();
  const [data, setData] = useState<any>(null);
  useEffect(() => {
    get(`/documents/${id}/alert`).then(setData);
  }, [id]);
  if (!data) return null;
  const doc = data.document;
  const guide = data.guide;
  return (
    <div className="phone-frame">
      <h1 style={{ color: 'var(--xm-danger)' }}>
        {doc.title} · 剩 {doc.daysLeft} 天
      </h1>
      <div className="card">
        去哪办：{guide.where}
        <br />
        带什么：{guide.bring?.join('、')}
        <br />
        线上：{guide.online ? '可' : '否'} · 耗时 {guide.etaHours}h · {guide.feeRange}
      </div>
      <button onClick={async () => { await post(`/documents/${id}/schedule`); alert('已生成办理日程'); }}>
        一键生成办理日程
      </button>
    </div>
  );
}

function Clipboard() {
  const [text, setText] = useState('下周三下午3点会议室A项目评审');
  const [draft, setDraft] = useState<any>(null);
  return (
    <div className="phone-frame">
      <h1>剪贴板识别</h1>
      <textarea value={text} onChange={(e) => setText(e.target.value)} style={{ width: '100%', minHeight: 90 }} />
      <button
        style={{ marginTop: 8 }}
        onClick={async () => {
          const res: any = await post('/events/from-clipboard', { text });
          setDraft(res.draft);
        }}
      >
        识别
      </button>
      {draft && (
        <div className="card">
          <div>标题：{draft.title}</div>
          <div>时间：{draft.startHint}</div>
          <div>地点：{draft.location}</div>
          <button
            style={{ marginTop: 8 }}
            onClick={async () => {
              await post('/events', {
                title: draft.title,
                start: '2026-10-15T15:00:00+08:00',
                end: '2026-10-15T16:00:00+08:00',
                location: draft.location,
              });
              alert('已建档');
            }}
          >
            一键确认
          </button>
        </div>
      )}
    </div>
  );
}

function Avatar() {
  const [stats, setStats] = useState<any>(null);
  useEffect(() => {
    get('/avatar/stats').then(setStats);
  }, []);
  return (
    <div className="phone-frame">
      <h1>分身档案</h1>
      <p className="muted">信任等级 {stats?.trustLevel}</p>
      <pre style={{ background: '#f5f5f5', padding: 12, borderRadius: 12 }}>{JSON.stringify(stats?.month, null, 2)}</pre>
      <Link to="/clipboard">剪贴板识别 →</Link>
    </div>
  );
}

function Family() {
  const [fam, setFam] = useState<any>(null);
  const load = () => get<any[]>('/families').then((x) => setFam(x[0]));
  useEffect(() => {
    load();
  }, []);
  if (!fam) return null;
  return (
    <div className="phone-frame">
      <h1>{fam.name}</h1>
      {fam.claims?.map((c: any) => (
        <div className="row" key={c.id}>
          <span>
            {c.title} · {c.claimant || '待认领'}
          </span>
          {!c.claimant && (
            <button
              onClick={async () => {
                await post(`/families/${fam.id}/claims/${c.id}/claim`, { name: '我' });
                load();
              }}
            >
              认领
            </button>
          )}
        </div>
      ))}
      <Link to="/family/med/med-dad">服药守护 →</Link>
    </div>
  );
}

function Me() {
  const [me, setMe] = useState<any>(null);
  useEffect(() => {
    get('/me').then(setMe);
  }, []);
  return (
    <div className="phone-frame">
      <h1>我的</h1>
      <p className="muted">
        {me?.displayName} · {me?.phone} · 方案{me?.storageMode}
      </p>
      <button onClick={async () => { await post('/sync/run'); alert('Mock 同步完成'); }}>同步日历源</button>
      <button style={{ marginLeft: 8 }} className="secondary" onClick={async () => { await post('/me/export'); alert('已导出'); }}>
        导出
      </button>
    </div>
  );
}

export default function App() {
  return (
    <Shell>
      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/timeline" element={<Timeline />} />
        <Route path="/avatar" element={<Avatar />} />
        <Route path="/family" element={<Family />} />
        <Route path="/me" element={<Me />} />
        <Route path="/events/:id/cheat-sheet" element={<CheatSheet />} />
        <Route path="/conflicts/:id" element={<Conflict />} />
        <Route path="/sign-off/:id" element={<SignOff />} />
        <Route path="/family/med/:id" element={<Med />} />
        <Route path="/life/birthday/:id" element={<Birthday />} />
        <Route path="/docs/:id/alert" element={<DocAlert />} />
        <Route path="/clipboard" element={<Clipboard />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </Shell>
  );
}
