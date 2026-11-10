import React from 'react';
import { Download, Sparkles, ShieldCheck, CheckCircle2, Star, Zap, Smartphone } from 'lucide-react';

export default function HeroInstallSection({ t }) {
  const isHi = !t?.code || t.code === 'hi';

  return (
    <section className="hero-section" id="download">
      <div className="hero-container">
        {/* Left Column: Text & Instant Install Hub */}
        <div className="hero-text-content">
          <div className="hero-tag">
            <Zap size={16} color="#0284C7" />
            <span>{t.hero?.badge || '⚡ देसी AI कृषि वैज्ञानिक • 24x7 सटीक मार्गदर्शन'}</span>
          </div>

          <h1 className="hero-heading">
            {isHi ? (
              <>
                स्मार्ट खेती से पैदावार बढ़ाएं,<br />
                <span style={{ color: 'var(--sky-primary)' }}>फसल रोग व पीलापन</span> सेकंडों में रोकें
              </>
            ) : (
              t.hero?.headline || 'Designed for farmers for better crop yield and expert agricultural guidance.'
            )}
          </h1>

          <p className="hero-subheadline">
            {isHi ? (
              <>
                <strong>लहसुन</strong> (पीलापन, थ्रिप्स, कंद फुलाव), <strong>अफीम</strong> (NDPS पट्टा, डोडा पोषण, खाखरिया सुरक्षा), <strong>गेहूं व प्याज</strong> की सटीक खाद, स्प्रे व रोग का 100% सटीक AI समाधान। बोलकर या लिखकर पूछें — ₹5,000 के फोन पर भी मक्खन जैसी स्पीड!
              </>
            ) : (
              t.hero?.subheadline
            )}
          </p>

          {/* High-Converting Install Buttons Hub */}
          <div className="hero-install-box">
            <div className="hero-cta-row">
              {/* Primary: Google Play Store Button */}
              <a
                href="https://play.google.com/store/apps/details?id=com.agfarmer.app"
                target="_blank"
                rel="noopener noreferrer"
                className="btn-google-play"
                id="play-store-btn"
              >
                <div className="play-icon-wrap">
                  <svg width="28" height="28" viewBox="0 0 24 24" fill="none">
                    <path d="M3.609 1.814L13.793 12 3.61 22.186c-.365-.365-.61-.926-.61-1.616V3.43c0-.69.245-1.25.61-1.616z" fill="#00C1A6"/>
                    <path d="M15.215 13.42l2.42 2.42-12.016 6.945 9.596-9.365z" fill="#FF3333"/>
                    <path d="M17.635 8.16L5.619 1.635l12.016 6.945-2.42 2.42z" fill="#FFBA00"/>
                    <path d="M17.635 15.84l3.415-1.972c.98-.566.98-1.488 0-2.054l-3.415-1.974-2.42 2.42 2.42 2.42z" fill="#00A0FF"/>
                  </svg>
                </div>
                <div className="play-text-wrap">
                  <span className="play-subtext">{isHi ? 'मुफ़्त में प्राप्त करें' : 'GET IT ON'}</span>
                  <span className="play-maintext">Google Play</span>
                </div>
                <div className="play-badge-pill">
                  <Star size={11} fill="#F59E0B" color="#F59E0B" />
                  <span>4.9 ★</span>
                </div>
              </a>

              {/* Secondary: Direct APK Instant Download */}
              <a
                href="/ag-farmer.apk"
                download="AG-Farmer.apk"
                className="btn-apk-direct"
                id="apk-download-btn"
              >
                <div className="apk-icon-wrap">
                  <Download size={22} color="#032B43" />
                </div>
                <div className="apk-text-wrap">
                  <span className="apk-subtext">{isHi ? 'डायरेक्ट फाइल डाउनलोड' : 'Direct APK File'}</span>
                  <span className="apk-maintext">{isHi ? 'APK डाउनलोड करें' : 'Download APK'}</span>
                </div>
                <span className="apk-size-pill">46 MB • सुपरफास्ट</span>
              </a>
            </div>

            {/* Trust checkmarks under CTAs */}
            <div className="hero-trust-badges">
              <span className="trust-item">
                <CheckCircle2 size={15} color="#16A34A" />
                <span>{isHi ? '100% मुफ़्त इंस्टॉलेशन' : '100% Free to Install'}</span>
              </span>
              <span className="trust-item">
                <ShieldCheck size={15} color="#0284C7" />
                <span>{isHi ? 'Play Protect द्वारा सुरक्षित' : 'Google Play Protect Verified'}</span>
              </span>
              <span className="trust-item">
                <Smartphone size={15} color="#0284C7" />
                <span>{isHi ? '2GB रैम वाले फोन पर भी स्मूथ' : 'Optimized for Budget Phones'}</span>
              </span>
            </div>
          </div>

          {/* Social Proof Stats */}
          <div className="hero-stats">
            <div>
              <div className="stat-num">{t.hero?.farmersCount || '10,000+'}</div>
              <div className="stat-label">{isHi ? 'संतुष्ट किसान भाई' : 'Active Farmers'}</div>
            </div>
            <div>
              <div className="stat-num">{t.hero?.accuracy || '98%'}</div>
              <div className="stat-label">{isHi ? 'सटीक रोग व खाद समाधान' : 'Diagnostic Accuracy'}</div>
            </div>
            <div>
              <div className="stat-num">{t.hero?.latency || '0ms'}</div>
              <div className="stat-label">{isHi ? 'सुपरफास्ट AI स्पीड' : 'Ultra-Fast Speed'}</div>
            </div>
          </div>
        </div>

        {/* Right Column: Interactive Phone Mockup with Visual Floating Highlights */}
        <div className="phone-mockup-wrapper">
          <div className="phone-mockup-card">
            <img
              src="/phone_mockup.jpg"
              alt="AG Farmer App Interface"
              className="phone-mockup-img"
              loading="eager"
            />
            {/* Quick Install overlay button on phone */}
            <a
              href="https://play.google.com/store/apps/details?id=com.agfarmer.app"
              target="_blank"
              rel="noopener noreferrer"
              className="phone-quick-install-pill"
            >
              <Download size={14} />
              <span>{isHi ? 'ऐप इंस्टॉल करें' : 'Install App'}</span>
            </a>
          </div>

          {/* Floating benefit badges */}
          <div className="floating-badge-1">
            <span>{t.hero?.floatingBadge1 || '🧄 लहसुन पीलापन 100% कंट्रोल'}</span>
          </div>

          <div className="floating-badge-2">
            <span>{t.hero?.floatingBadge2 || '🌸 अफीम डोडा व खाद सही समय पर'}</span>
          </div>

          <div className="floating-badge-3">
            <span>{isHi ? '🎙️ बोलकर पूछें — देसी हिंदी में जवाब' : '🎙️ Voice AI in Hindi'}</span>
          </div>
        </div>
      </div>
    </section>
  );
}

