import { PLAN_ORDER } from '../api.js';
import { Field, Check } from '../ui.jsx';

const TEXT_FIELDS = new Set(['deepPer', 'voicePer', 'liveMiniPer', 'videoPer']);
const BOOL_FIELDS = new Set(['rollsOver']);

export default function LimitsTab({ limits, setLimits, onSave, busy }) {
  function setPlan(id, field, value) {
    setLimits((prev) => ({
      ...prev,
      plans: {
        ...prev.plans,
        [id]: {
          ...prev.plans[id],
          [field]: TEXT_FIELDS.has(field) ? value : BOOL_FIELDS.has(field) ? value : Number(value),
        },
      },
    }));
  }

  return (
    <>
      <h1>APK लिमिट / शॉट</h1>
      <p className="sub">
        चैट, फोटो, AG Live mini, वीडियो stills — सब यहीं से। ऐप अपडेट की जरूरत नहीं। सेव के बाद अगली चैट से लागू।
      </p>

      <section className="card">
        <div className="row3">
          <Field
            label="बिना लॉगिन चैट"
            value={limits.guestChatLimit}
            onChange={(v) => setLimits({ ...limits, guestChatLimit: Number(v) })}
          />
          <Field
            label="बिना लॉगिन AG Live"
            value={limits.guestLiveLimit ?? 2}
            onChange={(v) => setLimits({ ...limits, guestLiveLimit: Number(v) })}
          />
          <Field
            label="बची चैट कितने दिन जुड़ें"
            value={limits.bankDays}
            onChange={(v) => setLimits({ ...limits, bankDays: Number(v) })}
          />
        </div>
      </section>

      {PLAN_ORDER.map((id) => {
        const plan = limits.plans?.[id];
        if (!plan) return null;
        return (
          <section className="card" key={id}>
            <div className="plan-head">
              <h2>{plan.label}</h2>
              <span>{id}</span>
            </div>
            <div className="grid">
              <Field label="रोज की कुल चैट" value={plan.totalChat} onChange={(v) => setPlan(id, 'totalChat', v)} />
              <Field label="मजबूत चैट" value={plan.strongChat} onChange={(v) => setPlan(id, 'strongChat', v)} />
              <Field label="फोटो जाँच" value={plan.image ?? 0} onChange={(v) => setPlan(id, 'image', v)} />
              <Field label="डीप रिसर्च" value={plan.deep} onChange={(v) => setPlan(id, 'deep', v)} />
              <Field label="लाइव आवाज़" value={plan.voice} onChange={(v) => setPlan(id, 'voice', v)} />
              <Field label="AG Live mini चैट" value={plan.liveMini ?? 0} onChange={(v) => setPlan(id, 'liveMini', v)} />
              <Field label="वीडियो stills (2.5 सेकंड)" value={plan.videoShots ?? 1} onChange={(v) => setPlan(id, 'videoShots', v)} />
              <Field label="वीडियो कॉल / दिन" value={plan.video ?? 0} onChange={(v) => setPlan(id, 'video', v)} />
              <label>
                वीडियो कॉल सीमा
                <select value={plan.videoPer || 'day'} onChange={(e) => setPlan(id, 'videoPer', e.target.value)}>
                  <option value="day">हर दिन</option>
                  <option value="none">अनलिमिटेड</option>
                </select>
              </label>
              <Field label="कोर्स आवाज़ / दिन" value={plan.courseVoice ?? 0} onChange={(v) => setPlan(id, 'courseVoice', v)} />
              <label>
                लाइव आवाज़ अवधि
                <select value={plan.voicePer || 'day'} onChange={(e) => setPlan(id, 'voicePer', e.target.value)} disabled={id === 'free'}>
                  <option value="day">हर दिन</option>
                  <option value="life">पूरी जिंदगी</option>
                </select>
              </label>
              <label>
                AG Live mini अवधि
                <select value={plan.liveMiniPer || 'day'} onChange={(e) => setPlan(id, 'liveMiniPer', e.target.value)}>
                  <option value="day">हर दिन</option>
                  <option value="month">हर महीना</option>
                  <option value="none">अनलिमिटेड mini</option>
                </select>
              </label>
              <label>
                डीप रिसर्च अवधि
                <select value={plan.deepPer} onChange={(e) => setPlan(id, 'deepPer', e.target.value)}>
                  <option value="day">हर दिन</option>
                  <option value="month">हर महीना</option>
                </select>
              </label>
              <Check
                label="बची चैट आगे जुड़ें"
                checked={id === 'free' ? false : plan.rollsOver}
                disabled={id === 'free'}
                onChange={(v) => setPlan(id, 'rollsOver', v)}
              />
            </div>
          </section>
        );
      })}

      <div className="actions">
        <button className="primary" disabled={busy} onClick={onSave}>
          {busy ? 'सेव हो रहा है…' : 'लिमिट सेव करो'}
        </button>
      </div>
    </>
  );
}
