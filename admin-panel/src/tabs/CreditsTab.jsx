import { call } from '../api.js';
import { Field } from '../ui.jsx';

export default function CreditsTab({
  api,
  adminKey,
  tokenVoice,
  setTokenVoice,
  tokenVideo,
  setTokenVideo,
  madeCode,
  setMadeCode,
  tokenRows,
  setTokenRows,
  busy,
  setBusy,
  setError,
}) {
  return (
    <>
      <h1>क्रेडिट टोकन</h1>
      <p className="sub">आवाज़ / वीडियो क्रेडिट का कोड बनाओ। किसान ऐप में रिडीम करेगा।</p>
      <section className="card">
        <div className="grid">
          <Field label="आवाज़ क्रेडिट" value={tokenVoice} onChange={setTokenVoice} />
          <Field label="वीडियो मिनट" value={tokenVideo} onChange={setTokenVideo} />
        </div>
        <div className="actions">
          <button
            className="primary"
            disabled={busy}
            onClick={async () => {
              setBusy(true);
              setError('');
              try {
                const body = await call(api, adminKey, 'credit.create', {
                  voice: Number(tokenVoice) || 0,
                  video: Number(tokenVideo) || 0,
                });
                setMadeCode(body.code || '');
                const list = await call(api, adminKey, 'admin.credit.list');
                setTokenRows(list.tokens || []);
              } catch (e) {
                setError(e.message);
              } finally {
                setBusy(false);
              }
            }}
          >
            टोकन बनाओ
          </button>
          {madeCode ? <span className="msg">{madeCode}</span> : null}
        </div>
        {tokenRows.length ? (
          <ul className="ann-list" style={{ marginTop: 14 }}>
            {tokenRows.map((row) => (
              <li key={row.code}>
                {row.code} · आवाज़ {row.voice} · वीडियो {row.video} · {row.used ? 'लग चुका' : 'नया'}
              </li>
            ))}
          </ul>
        ) : null}
      </section>
    </>
  );
}
