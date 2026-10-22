import { CROPS, cropLabel, call } from '../api.js';
import { Field } from '../ui.jsx';

export default function AnnounceTab({
  api,
  adminKey,
  announces,
  setAnnounces,
  crop,
  setCrop,
  title,
  setTitle,
  body,
  setBody,
  busy,
  setBusy,
  setError,
  setNote,
}) {
  async function publish() {
    setBusy(true);
    setError('');
    setNote('');
    try {
      const res = await call(api, adminKey, 'admin.announcement.create', {
        cropId: crop,
        titleHi: title,
        bodyHi: body,
      });
      setAnnounces(res.posts || []);
      setTitle('');
      setBody('');
      setNote('घोषणा लग गई। जानकारी पेज पर दिखेगी।');
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  }

  async function toggle(row) {
    setBusy(true);
    setError('');
    try {
      const res = await call(api, adminKey, 'admin.announcement.set', { id: row.id, active: !row.active });
      setAnnounces(res.posts || []);
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <h1>जानकारी घोषणा</h1>
      <p className="sub">फसल की घोषणा डालो। एक से ज़्यादा पोस्ट ऐप में स्वाइप होंगी।</p>
      <section className="card">
        <div className="row">
          <label>
            फसल
            <select value={crop} onChange={(e) => setCrop(e.target.value)}>
              {CROPS.map(([id, name]) => (
                <option key={id} value={id}>
                  {name}
                </option>
              ))}
            </select>
          </label>
          <Field label="शीर्षक" type="text" value={title} onChange={setTitle} />
        </div>
        <label style={{ marginTop: 12 }}>
          संदेश
          <textarea value={body} maxLength={700} onChange={(e) => setBody(e.target.value)} />
        </label>
        <div className="actions" style={{ marginTop: 12 }}>
          <button className="primary" disabled={busy} onClick={publish}>
            घोषणा डालो
          </button>
        </div>
        {announces.length ? (
          <ul className="ann-list">
            {announces.map((row) => (
              <li key={row.id} className={row.active ? '' : 'off'}>
                <strong>{row.titleHi}</strong>
                <span className="ann-meta">
                  {cropLabel(row.cropId)} · {row.createdAt ? new Date(row.createdAt).toLocaleString('hi-IN') : ''} ·{' '}
                  {row.active ? 'ऐप पर दिख रही' : 'छुपी हुई'}
                </span>
                <p>{row.bodyHi}</p>
                <button className="ghost" disabled={busy} onClick={() => toggle(row)}>
                  {row.active ? 'ऐप से छुपाओ' : 'फिर दिखाओ'}
                </button>
              </li>
            ))}
          </ul>
        ) : null}
      </section>
    </>
  );
}
