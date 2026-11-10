import React from 'react';
import { Check } from 'lucide-react';

export default function ComparisonSection({ t }) {
  if (!t.comparison) return null;

  return (
    <section className="section" id="comparison">
      <div className="section-title-wrap">
        <span className="section-pill">{t.comparison.pill}</span>
        <h2 className="section-heading">{t.comparison.title}</h2>
        <p className="section-desc">{t.comparison.subtitle}</p>
      </div>

      <div
        style={{
          overflowX: 'auto',
          background: '#FFFFFF',
          borderRadius: '24px',
          border: '1.4px solid var(--sky-ice)',
          boxShadow: '0 8px 30px rgba(3, 43, 67, 0.06)',
        }}
      >
        <table style={{ width: '100%', borderCollapse: 'collapse', minWidth: '640px' }}>
          <thead>
            <tr style={{ background: 'linear-gradient(135deg, var(--sky-deep), #024B79)', color: '#FFFFFF' }}>
              {t.comparison.headers.map((header, idx) => (
                <th
                  key={idx}
                  style={{
                    padding: '18px 20px',
                    textAlign: idx === 0 ? 'left' : 'center',
                    fontSize: '15px',
                    fontWeight: 900,
                    borderRight: idx < t.comparison.headers.length - 1 ? '1px solid rgba(186, 230, 253, 0.2)' : 'none',
                  }}
                >
                  {header}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {t.comparison.rows.map((row, rIdx) => (
              <tr
                key={rIdx}
                style={{
                  borderBottom: '1px solid var(--sky-ice)',
                  background: rIdx % 2 === 0 ? '#FFFFFF' : 'var(--sky-mist)',
                }}
              >
                <td style={{ padding: '16px 20px', fontWeight: 800, color: 'var(--sky-deep)', fontSize: '14.5px' }}>
                  {row[0]}
                </td>
                <td style={{ padding: '16px 20px', textAlign: 'center', color: '#64748B', fontSize: '14px' }}>
                  {row[1]}
                </td>
                <td style={{ padding: '16px 20px', textAlign: 'center', color: '#64748B', fontSize: '14px' }}>
                  {row[2]}
                </td>
                <td
                  style={{
                    padding: '16px 20px',
                    textAlign: 'center',
                    fontWeight: 800,
                    color: '#0284C7',
                    background: 'rgba(2, 132, 199, 0.08)',
                    fontSize: '14px',
                  }}
                >
                  <div style={{ display: 'inline-flex', alignItems: 'center', gap: '6px' }}>
                    <Check size={16} color="#0284C7" strokeWidth={3} />
                    <span>{row[3]}</span>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </section>
  );
}

