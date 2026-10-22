export default function CropsTab({ catalog, setCatalog, onSave, busy }) {
  const rows = Object.values(catalog.crops || {}).sort(
    (a, b) => Number(a.priority || 99) - Number(b.priority || 99),
  );

  function setCrop(id, field, value) {
    setCatalog((prev) => ({
      ...prev,
      crops: {
        ...prev.crops,
        [id]: { ...prev.crops[id], [field]: value },
      },
    }));
  }

  return (
    <>
      <h1>फसल कैटलॉग</h1>
      <p className="sub">कौन सी फसल किस प्लान में खुले, लाइव विश्लेषण, और ऐप पर दिखे या छुपे — यहीं से।</p>

      <section className="card table-wrap">
        <table>
          <thead>
            <tr>
              <th>फसल</th>
              <th>हिंदी</th>
              <th>न्यूनतम प्लान</th>
              <th>क्रम</th>
              <th>लाइव</th>
              <th>ऐप पर</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((crop) => (
              <tr key={crop.id}>
                <td>
                  {crop.emoji || ''} {crop.id}
                </td>
                <td>
                  <input
                    type="text"
                    value={crop.nameHi || ''}
                    onChange={(e) => setCrop(crop.id, 'nameHi', e.target.value)}
                  />
                </td>
                <td>
                  <select value={crop.minPlan || 'advanced'} onChange={(e) => setCrop(crop.id, 'minPlan', e.target.value)}>
                    <option value="advanced">₹299+</option>
                    <option value="all">₹599+ अफीम</option>
                    <option value="super">₹2650+</option>
                    <option value="distributor">₹13500</option>
                  </select>
                </td>
                <td>
                  <input
                    type="number"
                    min="1"
                    value={crop.priority ?? 99}
                    onChange={(e) => setCrop(crop.id, 'priority', Number(e.target.value))}
                  />
                </td>
                <td>
                  <input
                    type="checkbox"
                    checked={!!crop.hasLiveAnalysis}
                    onChange={(e) => setCrop(crop.id, 'hasLiveAnalysis', e.target.checked)}
                  />
                </td>
                <td>
                  <input
                    type="checkbox"
                    checked={crop.active !== false}
                    onChange={(e) => setCrop(crop.id, 'active', e.target.checked)}
                  />
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>

      <div className="actions">
        <button className="primary" disabled={busy} onClick={onSave}>
          {busy ? 'सेव हो रहा है…' : 'फसल सेव करो'}
        </button>
      </div>
    </>
  );
}
