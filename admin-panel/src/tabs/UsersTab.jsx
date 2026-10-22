import { useMemo, useState } from 'react';
import { PLAN_ORDER, PLAN_NAMES, call } from '../api.js';
import { Field } from '../ui.jsx';

const STATUS_HI = {
  online: 'ऑनलाइन',
  installed: 'इंस्टॉल',
  offline: 'ऑफलाइन',
  uninstalled: 'शायद अनइंस्टॉल',
  unknown: 'पता नहीं',
};

function when(ts) {
  if (!ts) return '—';
  const n = Number(ts);
  if (!n) return '—';
  return new Date(n).toLocaleString('hi-IN');
}

export default function UsersTab({
  api,
  adminKey,
  people,
  counts,
  reloadUsers,
  busy,
  setBusy,
  setError,
  setNote,
}) {
  const [q, setQ] = useState('');
  const [filter, setFilter] = useState('all');
  const [lookup, setLookup] = useState('');
  const [detail, setDetail] = useState(null);
  const [planId, setPlanId] = useState('advanced');
  const [block, setBlock] = useState(false);

  const rows = useMemo(() => {
    return (people || []).filter((row) => {
      if (filter === 'user' && row.kind !== 'user') return false;
      if (filter === 'guest' && row.kind !== 'guest') return false;
      if (filter === 'online' && row.status !== 'online') return false;
      const hay = `${row.email} ${row.name} ${row.uid} ${row.ip}`.toLowerCase();
      return !q || hay.includes(q.toLowerCase());
    });
  }, [people, filter, q]);

  async function loadOne(emailOrUid) {
    if (!emailOrUid) return;
    setBusy(true);
    setError('');
    try {
      const looksEmail = String(emailOrUid).includes('@');
      const body = await call(api, adminKey, 'admin.ai.user', looksEmail ? { email: emailOrUid } : { uid: emailOrUid });
      setDetail(body.user || body);
      setPlanId(body.user?.control?.planId || 'advanced');
      setBlock(!!body.user?.control?.blocked);
      const unlock = await call(api, adminKey, 'admin.unlock.get', { uid: body.user?.uid }).catch(() => null);
      if (unlock) setDetail((prev) => ({ ...prev, unlock: unlock.unlock }));
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  }

  async function setPlan(uid) {
    if (!uid) return;
    setBusy(true);
    setError('');
    try {
      await call(api, adminKey, 'admin.subscription', { uid, planId, status: 'active' });
      setNote('प्लान लग गया।');
      await reloadUsers();
      await loadOne(uid);
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  }

  async function setAi() {
    const uid = detail?.uid;
    const email = detail?.email;
    if (!uid && !email) return;
    setBusy(true);
    setError('');
    try {
      await call(api, adminKey, 'admin.ai.control', { uid, email, patch: { blocked: block, planId } });
      setNote(block ? 'इस यूज़र की AI बंद है।' : 'AI कंट्रोल सेव।');
      await loadOne(uid || email);
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  }

  async function grant(uid) {
    setBusy(true);
    setError('');
    try {
      await call(api, adminKey, 'admin.unlock.grant', { uid, amount: 0, note: 'admin_panel' });
      setNote('अनलॉक मिल गया।');
      await loadOne(uid);
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  }

  async function revoke(uid) {
    setBusy(true);
    setError('');
    try {
      await call(api, adminKey, 'admin.unlock.revoke', { uid });
      setNote('अनलॉक हटा।');
      await loadOne(uid);
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  }

  const quota = detail?.quota || {};

  return (
    <>
      <h1>यूज़र / गेस्ट</h1>
      <p className="sub">
        लॉगिन यूज़र और बिना लॉगिन गेस्ट — IP, लास्ट सीन, ऑनलाइन / इंस्टॉल / अनइंस्टॉल। चैट-कोर्स यादें यहाँ नहीं खुलतीं।
      </p>

      <section className="card">
        <div className="row3">
          <p className="stat">यूज़र {counts?.users ?? 0}</p>
          <p className="stat">गेस्ट {counts?.guests ?? 0}</p>
          <p className="stat">ऑनलाइन {counts?.online ?? 0}</p>
        </div>
        <div className="tabs" style={{ marginTop: 12, marginBottom: 0 }}>
          {[
            ['all', 'सब'],
            ['user', 'यूज़र'],
            ['guest', 'गेस्ट'],
            ['online', 'ऑनलाइन'],
          ].map(([id, label]) => (
            <button key={id} className={filter === id ? 'tab on' : 'tab'} onClick={() => setFilter(id)}>
              {label}
            </button>
          ))}
        </div>
        <div className="row" style={{ marginTop: 12 }}>
          <Field label="खोज (नाम / ईमेल / IP)" type="text" value={q} onChange={setQ} />
          <Field label="ईमेल या uid खोलो" type="text" value={lookup} onChange={setLookup} />
        </div>
        <div className="actions" style={{ marginTop: 12 }}>
          <button className="ghost" disabled={busy} onClick={reloadUsers}>
            सूची ताज़ा
          </button>
          <button className="primary" disabled={busy || !lookup} onClick={() => loadOne(lookup)}>
            यूज़र खोलो
          </button>
        </div>
      </section>

      {detail ? (
        <section className="card">
          <div className="plan-head">
            <h2>{detail.email || detail.uid}</h2>
            <span>{detail.uid}</span>
          </div>
          <p className="meta">
            कोटा चैट {quota.chatUsed ?? '—'} / {quota.chatCap ?? '—'} · फोटो {quota.imageUsed ?? '—'} / {quota.imageCap ?? '—'} ·
            Live mini {quota.liveMiniUsed ?? '—'} / {quota.liveMiniCap ?? '—'}
          </p>
          <div className="row3">
            <label>
              प्लान
              <select value={planId} onChange={(e) => setPlanId(e.target.value)}>
                {PLAN_ORDER.map((id) => (
                  <option key={id} value={id}>
                    {PLAN_NAMES[id]}
                  </option>
                ))}
              </select>
            </label>
            <label className="check" style={{ marginTop: 22 }}>
              <input type="checkbox" checked={block} onChange={(e) => setBlock(e.target.checked)} />
              AI बंद
            </label>
            <div className="actions" style={{ alignSelf: 'end' }}>
              <button className="primary" disabled={busy} onClick={() => setPlan(detail.uid)}>
                प्लान लगाओ
              </button>
              <button className="ghost" disabled={busy} onClick={setAi}>
                AI सेव
              </button>
            </div>
          </div>
          <div className="actions" style={{ marginTop: 12 }}>
            <button className="ghost" disabled={busy || !detail.uid} onClick={() => grant(detail.uid)}>
              अनलॉक दो
            </button>
            <button className="ghost" disabled={busy || !detail.uid} onClick={() => revoke(detail.uid)}>
              अनलॉक हटाओ
            </button>
            {detail.unlock?.unlocked ? <span className="msg">अनलॉक खुला</span> : <span className="meta">अनलॉक बंद</span>}
          </div>
        </section>
      ) : null}

      <section className="card table-wrap">
        <table>
          <thead>
            <tr>
              <th>किसान</th>
              <th>स्टेटस</th>
              <th>IP</th>
              <th>प्लान</th>
              <th>लास्ट सीन</th>
              <th>लॉगिन</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {rows.map((row) => (
              <tr key={row.uid || row.ipHash || row.ip}>
                <td>
                  <strong>{row.kind === 'guest' ? 'गेस्ट' : row.name || '—'}</strong>
                  <span className="meta" style={{ display: 'block' }}>
                    {row.email || row.uid || row.visitorId || '—'}
                    {row.reinstall ? ' · फिर इंस्टॉल' : ''}
                  </span>
                </td>
                <td>
                  <span className={`pill ${row.status}`}>{STATUS_HI[row.status] || row.status}</span>
                </td>
                <td>{row.ip || '—'}</td>
                <td>{row.kind === 'guest' ? 'गेस्ट' : PLAN_NAMES[row.plan] || row.plan}</td>
                <td>{when(row.lastSeen)}</td>
                <td>{when(row.lastLogin)}</td>
                <td>
                  {row.kind === 'user' ? (
                    <button className="ghost" disabled={busy} onClick={() => loadOne(row.email || row.uid)}>
                      खोलो
                    </button>
                  ) : (
                    <span className="meta">गेस्ट</span>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {!rows.length ? <p className="meta">कोई पंक्ति नहीं।</p> : null}
      </section>
    </>
  );
}
