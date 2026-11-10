import React, { useState, useEffect } from 'react';
import { Download, Star } from 'lucide-react';

export default function StickyBottomInstallBar({ t }) {
  const [visible, setVisible] = useState(false);
  const isHi = !t?.code || t.code === 'hi';

  useEffect(() => {
    const handleScroll = () => {
      // Show when scrolled past 280px
      if (window.scrollY > 280) {
        setVisible(true);
      } else {
        setVisible(false);
      }
    };
    window.addEventListener('scroll', handleScroll, { passive: true });
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  if (!visible) return null;

  return (
    <aside className="sticky-mobile-install-bar" aria-label="Quick App Install">
      <div className="sticky-mobile-inner">
        <div className="sticky-app-info">
          <img
            src="/ag_farmer_logo.png"
            alt="AG Farmer"
            className="sticky-app-icon"
          />
          <div className="sticky-text-wrap">
            <span className="sticky-app-name">AG Farmer AI</span>
            <span className="sticky-app-sub">
              <span className="sticky-stars">
                <Star size={11} fill="#F59E0B" color="#F59E0B" /> 4.9 ★
              </span>
              {' '}• {isHi ? '100% मुफ़्त' : 'Free App'}
            </span>
          </div>
        </div>

        <a
          href="https://play.google.com/store/apps/details?id=com.agfarmer.app"
          target="_blank"
          rel="noopener noreferrer"
          className="sticky-install-btn"
        >
          <Download size={16} />
          <span>{isHi ? 'इंस्टॉल करें' : 'Install'}</span>
        </a>
      </div>
    </aside>
  );
}

