import React, { useState } from 'react';
import { Check, ArrowRight } from 'lucide-react';

export default function CropsSection({ t }) {
  const [selectedCrop, setSelectedCrop] = useState('garlic');
  const details = t.crops.details[selectedCrop] || t.crops.details.garlic;

  return (
    <section className="section" id="crops" style={{ background: 'var(--sky-soft)', borderRadius: '36px' }}>
      <div className="section-title-wrap">
        <span className="section-pill">{t.crops.pill}</span>
        <h2 className="section-heading">{t.crops.title}</h2>
        <p className="section-desc">{t.crops.subtitle}</p>
      </div>

      <div className="crop-tabs">
        {t.crops.tabs.map((crop) => (
          <button
            key={crop.id}
            className={`crop-tab-btn ${selectedCrop === crop.id ? 'active' : ''}`}
            onClick={() => setSelectedCrop(crop.id)}
          >
            <span>{crop.icon}</span>
            <span>{crop.name}</span>
          </button>
        ))}
      </div>

      <div className="crop-detail-card">
        <div>
          <h3 className="crop-detail-title">{details.title}</h3>
          <p style={{ color: 'var(--text-muted)', marginBottom: '20px', fontSize: '15px' }}>
            AG Farmer में इस फसल का संपूर्ण 120-150 दिनों का वैज्ञानिक कैलेंडर और रोग निदान उपलब्ध है।
          </p>

          <div>
            {details.points.map((point, pIdx) => (
              <div className="crop-point" key={pIdx}>
                <Check className="crop-point-icon" size={20} />
                <span>{point}</span>
              </div>
            ))}
          </div>

          <div style={{ marginTop: '24px' }}>
            <a
              href="https://play.google.com/store/apps/details?id=com.agfarmer.app"
              target="_blank"
              rel="noopener noreferrer"
              className="btn-primary"
              style={{ padding: '12px 22px', fontSize: '14px' }}
            >
              <span>इस फसल का VIP शेड्यूल देखें</span>
              <ArrowRight size={16} />
            </a>
          </div>
        </div>

        <div
          style={{
            background: 'var(--sky-mist)',
            borderRadius: '22px',
            padding: '24px',
            border: '1.2px solid var(--sky-ice)',
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '16px' }}>
            <img
              src="/ag_farmer_logo.png"
              alt="Logo"
              style={{ width: '48px', height: '48px', borderRadius: '14px' }}
            />
            <div>
              <strong style={{ display: 'block', color: 'var(--sky-deep)' }}>AG Farmer AI Assistant</strong>
              <span style={{ fontSize: '12px', color: '#0284C7', fontWeight: 800 }}>⚡ लाइव वैज्ञानिक सहायता</span>
            </div>
          </div>

          <div
            style={{
              background: '#FFFFFF',
              borderRadius: '16px',
              padding: '16px',
              border: '1px solid var(--sky-ice)',
              marginBottom: '12px',
            }}
          >
            <p style={{ fontSize: '13.5px', color: 'var(--text-body)', margin: 0 }}>
              "किसान भाई, मौसम में नमी बढ़ने पर तुरंत फंगस स्प्रे करें। सही समय पर सही दवा डालने से आपकी फसल की उपज 30-40% तक बढ़ेगी।"
            </p>
          </div>

          <div style={{ textAlign: 'right', fontSize: '12px', color: 'var(--text-muted)', fontWeight: 600 }}>
            ✓ सत्यापित कृषि वैज्ञानिक डेटाबेस
          </div>
        </div>
      </div>
    </section>
  );
}

