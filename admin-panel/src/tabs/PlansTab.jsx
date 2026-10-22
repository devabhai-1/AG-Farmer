import { PLAN_ORDER, PLAN_NAMES } from '../api.js';
import { Field, Check } from '../ui.jsx';

export default function PlansTab({ catalog, setCatalog, onSave, busy }) {
  function setPlan(id, field, value) {
    setCatalog((prev) => ({
      ...prev,
      plans: {
        ...prev.plans,
        [id]: {
          ...prev.plans[id],
          [field]: value,
        },
      },
    }));
  }

  return (
    <>
      <h1>प्लान कैटलॉग</h1>
      <p className="sub">
        प्लान का मूल दाम फिक्स है। छूट का दाम लिखो — ऐप वही दिखाएगा, Razorpay उसी से चार्ज करेगा। 0 = बिना छूट।
      </p>

      {PLAN_ORDER.map((id) => {
        const plan = catalog.plans?.[id];
        if (!plan) return null;
        return (
          <section className="card" key={id}>
            <div className="plan-head">
              <h2>{PLAN_NAMES[id] || plan.nameHi || id}</h2>
              <span>{id}</span>
            </div>
            <div className="grid">
              <label>
                फिक्स दाम ₹
                <input type="number" value={plan.priceInr ?? 0} readOnly disabled />
              </label>
              <Field
                label="छूट के बाद ₹"
                value={plan.saleInr ?? 0}
                onChange={(v) => setPlan(id, 'saleInr', Number(v))}
              />
              <p className="meta" style={{ gridColumn: '1 / -1', margin: '0 0 4px' }}>
                {Number(plan.saleInr) > 0 && Number(plan.saleInr) < Number(plan.priceInr)
                  ? `ऐप ₹${plan.saleInr} लिखेगा, ₹${plan.priceInr} कटेगा। Razorpay ₹${plan.saleInr} लेगा।`
                  : `छूट नहीं। ऐप और Razorpay दोनों ₹${plan.priceInr || 0}।`}
              </p>
              <Field label="अंग्रेज़ी नाम" type="text" value={plan.nameEn || ''} onChange={(v) => setPlan(id, 'nameEn', v)} />
              <Field label="हिंदी नाम" type="text" value={plan.nameHi || ''} onChange={(v) => setPlan(id, 'nameHi', v)} />
              <Field label="बैज EN" type="text" value={plan.badgeEn || ''} onChange={(v) => setPlan(id, 'badgeEn', v)} />
              <Field label="बैज HI" type="text" value={plan.badgeHi || ''} onChange={(v) => setPlan(id, 'badgeHi', v)} />
              <Check label="ऐप पर बिके" checked={plan.active !== false} onChange={(v) => setPlan(id, 'active', v)} />
              <Check label="कोर्स खुले" checked={!!plan.courses} onChange={(v) => setPlan(id, 'courses', v)} />
              <Check label="अफीम शामिल" checked={!!plan.includesAfim} onChange={(v) => setPlan(id, 'includesAfim', v)} />
              <Check label="अनुशंसित" checked={!!plan.recommended} onChange={(v) => setPlan(id, 'recommended', v)} />
            </div>
          </section>
        );
      })}

      <div className="actions">
        <button className="primary" disabled={busy} onClick={onSave}>
          {busy ? 'सेव हो रहा है…' : 'प्लान सेव करो'}
        </button>
      </div>
    </>
  );
}
