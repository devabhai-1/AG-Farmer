import React, { useEffect, useState } from 'react';
import { Check, ArrowRight } from 'lucide-react';

const PLAN_IDS = ['free', 'advanced', 'all', 'super', 'distributor'];

function payLabel(row) {
  const mrp = Math.round(Number(row?.priceInr) || 0);
  const sale = Math.round(Number(row?.saleInr) || 0);
  if (sale > 0 && sale < mrp) return { pay: sale, mrp };
  return { pay: mrp, mrp: null };
}

export default function PricingSection({ t }) {
  const [live, setLive] = useState(null);

  useEffect(() => {
    let stop = false;
    fetch('https://api.ag-farmer.com/api', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ action: 'catalog.plans' }),
    })
      .then((r) => r.json())
      .then((body) => {
        if (stop || !body?.plans) return;
        setLive(body.plans);
      })
      .catch(() => {});
    return () => {
      stop = true;
    };
  }, []);

  return (
    <section className="section" id="pricing">
      <div className="section-title-wrap">
        <span className="section-pill">{t.pricing.pill}</span>
        <h2 className="section-heading">{t.pricing.title}</h2>
        <p className="section-desc">{t.pricing.subtitle}</p>
      </div>

      <div className="pricing-grid">
        {t.pricing.plans.map((plan, index) => {
          const catalog = live?.[PLAN_IDS[index]];
          const cut = catalog ? payLabel(catalog) : null;
          return (
            <div className={`pricing-card ${plan.featured ? 'featured' : ''}`} key={index}>
              {plan.featured && <div className="pricing-badge">{plan.badge}</div>}
              <div>
                <h3 className="plan-name">{plan.name}</h3>
                <div className="plan-price">
                  {cut ? `₹${cut.pay}` : plan.price} <span>/ {plan.period}</span>
                  {cut?.mrp ? (
                    <s style={{ marginLeft: 8, fontSize: '0.85em', opacity: 0.55 }}>₹{cut.mrp}</s>
                  ) : null}
                </div>

                <ul className="plan-features">
                  {plan.features.map((feat, fIndex) => (
                    <li key={fIndex}>
                      <Check size={18} color="#0284C7" />
                      <span>{feat}</span>
                    </li>
                  ))}
                </ul>
              </div>

              <a
                href="#download"
                className={plan.featured ? 'btn-primary' : 'btn-secondary'}
                style={{ textAlign: 'center', justifyContent: 'center' }}
              >
                <span>{plan.cta}</span>
                <ArrowRight size={16} />
              </a>
            </div>
          );
        })}
      </div>
    </section>
  );
}
