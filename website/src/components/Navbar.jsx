import React from 'react';
import { Globe, Download, Sparkles } from 'lucide-react';

export default function Navbar({ t, onOpenLanguageModal, currentLang }) {
  const isHindi = currentLang === 'hi';

  return (
    <header className="navbar">
      <a href="#" className="nav-brand">
        <img
          src="/ag_farmer_logo.png"
          alt="AG Farmer Logo"
          className="nav-logo"
        />
        <div>
          <span className="nav-brand-title">AG Farmer</span>
          <span className="nav-brand-tag">{t.nav?.tagline || 'AI कृषि सहायक'}</span>
        </div>
      </a>

      <ul className="nav-links">
        <li><a href="#features">{t.nav?.features || 'खास फीचर्स'}</a></li>
        <li><a href="#crops">{t.nav?.crops || 'फसलें'}</a></li>
        <li><a href="#how-it-works">{t.nav?.howItWorks || 'कैसे काम करता है'}</a></li>
        <li><a href="#pricing">{t.nav?.pricing || 'प्लान्स'}</a></li>
        <li><a href="#reviews">{t.nav?.reviews || 'समीक्षाएं'}</a></li>
        <li><a href="#legal">{t.nav?.legal || 'लीगल'}</a></li>
      </ul>

      <div className="nav-actions">
        <button
          className="lang-switch-btn"
          onClick={onOpenLanguageModal}
          title="Change Language / भाषा बदलें"
          aria-label="Change Language"
        >
          <Globe size={15} />
          <span>{isHindi ? '🇮🇳 हिन्दी' : '🇬🇧 English'}</span>
        </button>

        <a
          href="https://play.google.com/store/apps/details?id=com.agfarmer.app"
          target="_blank"
          rel="noopener noreferrer"
          className="nav-download-btn"
        >
          <Download size={15} />
          <span>{isHindi ? 'अभी इंस्टॉल करें' : 'Install Free'}</span>
        </a>
      </div>
    </header>
  );
}

