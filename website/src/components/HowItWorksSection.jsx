import React from 'react';

export default function HowItWorksSection({ t }) {
  return (
    <section className="section" id="how-it-works">
      <div className="section-title-wrap">
        <span className="section-pill">{t.howItWorks.pill}</span>
        <h2 className="section-heading">{t.howItWorks.title}</h2>
        <p className="section-desc">{t.howItWorks.subtitle}</p>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: '24px' }}>
        {t.howItWorks.steps.map((step, idx) => (
          <div
            key={idx}
            style={{
              background: '#FFFFFF',
              border: '1.4px solid var(--sky-ice)',
              borderRadius: '24px',
              padding: '32px 24px',
              boxShadow: '0 8px 24px rgba(3, 43, 67, 0.05)',
              position: 'relative',
            }}
          >
            <div
              style={{
                display: 'inline-block',
                background: 'linear-gradient(135deg, var(--sky-deep), var(--sky-primary))',
                color: 'white',
                fontWeight: 900,
                fontSize: '18px',
                padding: '6px 16px',
                borderRadius: '14px',
                marginBottom: '16px',
              }}
            >
              कदम {step.step}
            </div>
            <h3 style={{ fontSize: '20px', fontWeight: 800, color: 'var(--sky-deep)', marginBottom: '10px' }}>
              {step.title}
            </h3>
            <p style={{ fontSize: '15px', color: 'var(--text-muted)', lineHeight: '1.6' }}>
              {step.desc}
            </p>
          </div>
        ))}
      </div>
    </section>
  );
}

