import { call } from '../api.js';

function rowsOf(requests) {
  if (!requests) return [];
  if (Array.isArray(requests)) return requests;
  return Object.entries(requests).map(([id, row]) => ({ id, ...row }));
}

export default function SupportTab({ api, adminKey, requests, setRequests, busy, setBusy, setError, setNote }) {
  const rows = rowsOf(requests).sort((a, b) => Number(b.updatedAt || 0) - Number(a.updatedAt || 0));

  async function setStatus(row, status) {
    setBusy(true);
    setError('');
    try {
      await call(api, adminKey, 'admin.support.update', { id: row.id, status });
      const body = await call(api, adminKey, 'admin.support.list');
      setRequests(body.requests || {});
      setNote('सपोर्ट अपडेट हो गया।');
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <h1>सपोर्ट</h1>
      <p className="sub">ऐप से आई लाइव/टोकन रिक्वेस्ट। यहाँ से pending / done करो।</p>
      <section className="card">
        {!rows.length ? <p className="meta">कोई रिक्वेस्ट नहीं।</p> : null}
        <ul className="ann-list">
          {rows.map((row) => (
            <li key={row.id} className={row.status === 'done' || row.status === 'closed' ? 'off' : ''}>
              <strong>{row.userEmail || row.email || row.uid}</strong>
              <span className="ann-meta">
                {row.planId || '—'} · {row.status} · {row.createdAt || ''}
              </span>
              <p>{row.message}</p>
              <div className="actions">
                <button className="ghost" disabled={busy} onClick={() => setStatus(row, 'done')}>
                  हो गया
                </button>
                <button className="ghost" disabled={busy} onClick={() => setStatus(row, 'pending')}>
                  वापस pending
                </button>
              </div>
            </li>
          ))}
        </ul>
      </section>
    </>
  );
}
