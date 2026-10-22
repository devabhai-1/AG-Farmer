export default function ServerTab({ metrics, analytics, system }) {
  const totals = metrics?.totals || {};
  const pages = Object.entries(analytics?.pages || {}).sort((a, b) => (b[1].visits || 0) - (a[1].visits || 0));
  const models = system?.config?.models || {};

  return (
    <>
      <h1>सर्वर / पेज</h1>
      <p className="sub">सिर्फ आँकड़े। मॉडल नाम .env से आते हैं — चाबी यहाँ नहीं बदलती।</p>

      <section className="card">
        <div className="plan-head">
          <h2>API</h2>
          <span>uptime {metrics?.uptimeSec ? Math.round(metrics.uptimeSec / 60) : 0} मि</span>
        </div>
        <div className="row3">
          <p className="stat">रिक्वेस्ट {totals.requests || 0}</p>
          <p className="stat">4xx {totals.status4xx || 0}</p>
          <p className="stat">5xx {totals.status5xx || 0}</p>
        </div>
        <p className="meta">
          p95 {metrics?.latencyMs?.p95 || 0} ms · RAM {metrics?.process?.rssMb || 0} MB
        </p>
      </section>

      <section className="card">
        <div className="plan-head">
          <h2>मॉडल (पढ़ने के लिए)</h2>
        </div>
        <ul className="plain">
          {Object.entries(models).map(([k, v]) => (
            <li key={k}>
              {k}: {String(v || '—')}
            </li>
          ))}
        </ul>
      </section>

      <section className="card table-wrap">
        <div className="plan-head">
          <h2>पेज विज़िट</h2>
          <span>कुल {analytics?.summary?.totalVisits || 0}</span>
        </div>
        <table>
          <thead>
            <tr>
              <th>पेज</th>
              <th>विज़िट</th>
            </tr>
          </thead>
          <tbody>
            {pages.map(([id, row]) => (
              <tr key={id}>
                <td>{id}</td>
                <td>{row.visits || 0}</td>
              </tr>
            ))}
          </tbody>
        </table>
        {!pages.length ? <p className="meta">अभी आँकड़ा नहीं।</p> : null}
      </section>
    </>
  );
}
