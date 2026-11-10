import React from 'react';
import { ShieldCheck, FileText, Mail, Trash2, ArrowRight } from 'lucide-react';

export default function LegalSection({ t }) {
  const icons = [
    <ShieldCheck size={24} color="#0284C7" />,
    <FileText size={24} color="#0284C7" />,
    <Mail size={24} color="#0284C7" />,
    <Trash2 size={24} color="#EF4444" />,
  ];

  return (
    <section className="section" id="legal">
      <div className="section-title-wrap">
        <span className="section-pill">{t.legal.pill}</span>
        <h2 className="section-heading">{t.legal.title}</h2>
        <p className="section-desc">{t.legal.subtitle}</p>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(260px, 1fr))', gap: '20px' }}>
        {t.legal.links.map((link, idx) => (
          <a
            key={idx}
            href={link.url}
            target="_blank"
            rel="noopener noreferrer"
            style={{
              background: '#FFFFFF',
              border: '1.4px solid var(--sky-ice)',
              borderRadius: '20px',
              padding: '24px',
              textDecoration: 'none',
              color: 'inherit',
              boxShadow: '0 6px 20px rgba(3, 43, 67, 0.05)',
              display: 'flex',
              flexDirection: 'column',
              justifyContent: 'space-between',
              transition: 'all 0.2s',
            }}
            onMouseOver={(e) => {
              e.currentTarget.style.borderColor = 'var(--sky-primary)';
              e.currentTarget.style.transform = 'translateY(-3px)';
            }}
            onMouseOut={(e) => {
              e.currentTarget.style.borderColor = 'var(--sky-ice)';
              e.currentTarget.style.transform = 'none';
            }}
          >
            <div>
              <div style={{ marginBottom: '14px' }}>{icons[idx] || icons[0]}</div>
              <h3 style={{ fontSize: '18px', fontWeight: 800, color: 'var(--sky-deep)', marginBottom: '6px' }}>
                {link.name}
              </h3>
              <p style={{ fontSize: '13.5px', color: 'var(--text-muted)' }}>{link.desc}</p>
            </div>

            <div
              style={{
                marginTop: '18px',
                display: 'flex',
                alignItems: 'center',
                gap: '4px',
                color: 'var(--sky-primary)',
                fontWeight: 800,
                fontSize: '13px',
              }}
            >
              <span>दस्तावेज़ खोलें (Read Document)</span>
              <ArrowRight size={16} />
            </div>
          </a>
        ))}
      </div>
    </section>
  );
}

