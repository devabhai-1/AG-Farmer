import React, { useState, useEffect } from 'react';
import { translations } from './translations.js';
import Navbar from './components/Navbar.jsx';
import HeroInstallSection from './components/HeroInstallSection.jsx';
import FeaturesSection from './components/FeaturesSection.jsx';
import CropsSection from './components/CropsSection.jsx';
import HowItWorksSection from './components/HowItWorksSection.jsx';
import PricingSection from './components/PricingSection.jsx';
import ComparisonSection from './components/ComparisonSection.jsx';
import FaqSection from './components/FaqSection.jsx';
import ReviewsSection from './components/ReviewsSection.jsx';
import LegalSection from './components/LegalSection.jsx';
import Footer from './components/Footer.jsx';
import StickyBottomInstallBar from './components/StickyBottomInstallBar.jsx';
import LanguageGatewayModal from './components/LanguageGatewayModal.jsx';

export default function App() {
  const [lang, setLang] = useState('hi');
  // Ad traffic lands DIRECTLY on the High-Converting Install Hero without blocking popups!
  const [showLangModal, setShowLangModal] = useState(false);

  useEffect(() => {
    const saved = localStorage.getItem('ag_farmer_lang');
    if (saved === 'hi' || saved === 'en') {
      setLang(saved);
    }
  }, []);

  const handleSelectLang = (newLang) => {
    setLang(newLang);
    setShowLangModal(false);
    localStorage.setItem('ag_farmer_lang', newLang);
  };

  const t = translations[lang] || translations.hi;

  return (
    <div className="app-root">
      {showLangModal && (
        <LanguageGatewayModal
          onSelectLanguage={handleSelectLang}
          initialLang={lang}
          onClose={() => setShowLangModal(false)}
        />
      )}

      <Navbar
        t={t}
        onOpenLanguageModal={() => setShowLangModal(true)}
        currentLang={lang}
      />

      <main>
        <HeroInstallSection t={t} />
        <FeaturesSection t={t} />
        <CropsSection t={t} />
        <HowItWorksSection t={t} />
        <PricingSection t={t} />
        <ComparisonSection t={t} />
        <FaqSection t={t} />
        <ReviewsSection t={t} />
        <LegalSection t={t} />
      </main>

      <Footer t={t} />

      {/* Floating mobile install CTA for incoming ad traffic */}
      <StickyBottomInstallBar t={t} />
    </div>
  );
}

