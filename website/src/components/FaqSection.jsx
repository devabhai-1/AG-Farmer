import React, { useState } from 'react';
import { ChevronDown } from 'lucide-react';

export default function FaqSection({ t }) {
  const [openIndex, setOpenIndex] = useState(0);

  if (!t.faq) return null;

  const toggle = (idx) => {
    setOpenIndex(openIndex === idx ? null : idx);
  };

  return (
    <section className="section" id="faq">
      <div className="section-title-wrap">
        <span className="section-pill">{t.faq.pill}</span>
        <h2 className="section-heading">{t.faq.title}</h2>
        <p className="section-desc">{t.faq.subtitle}</p>
      </div>

      <div style={{ maxWidth: '840px', margin: '0 auto', display: 'flex', flexDirection: 'column', gap: '14px' }}>
        {t.faq.items.map((item, idx) => {
          const isOpen = openIndex === idx;
          return (
            <div
              key={idx}
              style={{
                background: '#FFFFFF',
                border: '1.4px solid',
                borderColor: isOpen ? 'var(--sky-primary)' : 'var(--sky-ice)',
                borderRadius: '18px',
                overflow: 'hidden',
                transition: 'all 0.2s ease',
                boxShadow: isOpen
                  ? '0 10px 28px rgba(2, 132, 199, 0.12)'
                  : '0 4px 14px rgba(3, 43, 67, 0.04)',
              }}
            >
              <button
                onClick={() => toggle(idx)}
                style={{
                  width: '100%',
                  textAlign: 'left',
                  background: 'none',
                  border: 'none',
                  padding: '20px 22px',
                  display: 'flex',
                  justifyContent: 'space-between',
                  alignItems: 'center',
                  cursor: 'pointer',
                  gap: '14px',
                }}
              >
                <span
                  style={{
                    fontSize: '16.5px',
                    fontWeight: 800,
                    color: isOpen ? 'var(--sky-primary)' : 'var(--sky-deep)',
                    lineHeight: 1.4,
                  }}
                >
                  {item.q}
                </span>
                <ChevronDown
                  size={20}
                  color={isOpen ? '#0284C7' : '#64748B'}
                  style={{
                    transform: isOpen ? 'rotate(180deg)' : 'rotate(0deg)',
                    transition: 'transform 0.25s ease',
                    flexShrink: 0,
                  }}
                />
              </button>

              {isOpen && (
                <div
                  style={{
                    padding: '0 22px 22px',
                    fontSize: '15px',
                    color: 'var(--text-body)',
                    lineHeight: '1.7',
                    borderTop: '1px solid var(--sky-soft)',
                    paddingTop: '16px',
                  }}
                >
                  {item.a}
                </div>
              )}
            </div>
          );
        })}
      </div>
    </section>
  );
}

