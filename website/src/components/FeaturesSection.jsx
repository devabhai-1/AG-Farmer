import React from 'react';

export default function FeaturesSection({ t }) {
  return (
    <section className="section" id="features">
      <div className="section-title-wrap">
        <span className="section-pill">{t.features.pill}</span>
        <h2 className="section-heading">{t.features.title}</h2>
        <p className="section-desc">{t.features.subtitle}</p>
      </div>

      <div className="features-grid">
        {t.features.items.map((item, idx) => (
          <div className="feature-card" key={idx}>
            <div className="feature-icon-box">{item.icon}</div>
            <h3 className="feature-title">{item.title}</h3>
            <p className="feature-desc">{item.desc}</p>
          </div>
        ))}
      </div>
    </section>
  );
}

