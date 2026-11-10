import React from 'react';
import { Star } from 'lucide-react';

export default function ReviewsSection({ t }) {
  return (
    <section className="section" id="reviews" style={{ background: 'var(--sky-mist)' }}>
      <div className="section-title-wrap">
        <span className="section-pill">{t.reviews.pill}</span>
        <h2 className="section-heading">{t.reviews.title}</h2>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))', gap: '24px' }}>
        {t.reviews.items.map((item, idx) => (
          <div
            key={idx}
            style={{
              background: '#FFFFFF',
              border: '1.4px solid var(--sky-ice)',
              borderRadius: '24px',
              padding: '30px 24px',
              boxShadow: '0 8px 24px rgba(3, 43, 67, 0.05)',
              display: 'flex',
              flexDirection: 'column',
              justifyContent: 'space-between',
            }}
          >
            <div>
              <div style={{ display: 'flex', gap: '4px', color: '#F59E0B', marginBottom: '14px' }}>
                {[...Array(5)].map((_, sIdx) => (
                  <Star key={sIdx} size={16} fill="#F59E0B" color="#F59E0B" />
                ))}
              </div>
              <p
                style={{
                  fontSize: '15px',
                  color: 'var(--text-body)',
                  lineHeight: '1.65',
                  marginBottom: '20px',
                  fontStyle: 'italic',
                }}
              >
                "{item.quote}"
              </p>
            </div>

            <div
              style={{
                borderTop: '1px solid var(--sky-ice)',
                paddingTop: '16px',
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center',
              }}
            >
              <div>
                <strong style={{ display: 'block', color: 'var(--sky-deep)', fontSize: '15px' }}>
                  {item.author}
                </strong>
                <span style={{ fontSize: '13px', color: 'var(--text-muted)' }}>{item.location}</span>
              </div>
              <span
                style={{
                  fontSize: '12px',
                  background: 'var(--sky-soft)',
                  color: '#03446E',
                  fontWeight: 800,
                  padding: '4px 10px',
                  borderRadius: '12px',
                }}
              >
                {item.crop}
              </span>
            </div>
          </div>
        ))}
      </div>
    </section>
  );
}

