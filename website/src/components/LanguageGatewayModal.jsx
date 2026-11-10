import React, { useState } from 'react';
import { X } from 'lucide-react';

export default function LanguageGatewayModal({ onSelectLanguage, initialLang = 'hi', onClose }) {
  const [selected, setSelected] = useState(initialLang);

  const languages = [
    { code: 'hi', name: 'हिन्दी', sub: 'भारतीय किसानों की अपनी भाषा', flag: '🇮🇳', popular: true },
    { code: 'en', name: 'English', sub: 'Standard Global Language', flag: '🇬🇧', popular: false },
  ];

  return (
    <div className="lang-gateway-backdrop" id="language-gateway" onClick={onClose}>
      <div className="lang-gateway-modal" onClick={(e) => e.stopPropagation()}>
        {onClose && (
          <button
            onClick={onClose}
            style={{
              position: 'absolute',
              top: '18px',
              right: '18px',
              background: 'var(--sky-soft)',
              border: 'none',
              borderRadius: '50%',
              width: '36px',
              height: '36px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              cursor: 'pointer',
              color: 'var(--sky-deep)',
            }}
            aria-label="Close"
          >
            <X size={20} />
          </button>
        )}

        <div className="lang-logo-badge">
          <img src="/ag_farmer_logo.png" alt="AG Farmer Logo" />
        </div>

        <h2 className="lang-gateway-title">
          {selected === 'en' ? 'Choose Your Language' : 'अपनी भाषा चुनें'}
        </h2>
        <p className="lang-gateway-subtitle">
          {selected === 'en'
            ? 'Select your preferred language for AG Farmer:'
            : 'AG Farmer में आपका स्वागत है। कृपया अपनी भाषा चुनें:'}
        </p>

        <div className="lang-options-grid">
          {languages.map((item) => (
            <button
              key={item.code}
              className={`lang-card-btn ${selected === item.code ? 'active' : ''}`}
              onClick={() => setSelected(item.code)}
            >
              <span className="lang-flag">{item.flag}</span>
              <div>
                <div className="lang-name">{item.name}</div>
                <div className="lang-desc">{item.sub}</div>
              </div>
            </button>
          ))}
        </div>

        <button
          className="lang-continue-btn"
          onClick={() => onSelectLanguage(selected)}
        >
          {selected === 'en' ? 'Continue →' : 'आगे बढ़ें →'}
        </button>
      </div>
    </div>
  );
}

