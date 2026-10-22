import React from 'react';

export default function Footer({ t }) {
  return (
    <footer className="footer">
      <div className="footer-container">
        <div className="footer-brand">
          <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '14px' }}>
            <img
              src="/ag_farmer_logo.png"
              alt="AG Farmer"
              style={{ width: '48px', height: '48px', borderRadius: '14px', border: '1.5px solid var(--sky-ice)' }}
            />
            <div>
              <span style={{ fontSize: '22px', fontWeight: 900, color: 'white' }}>AG Farmer</span>
              <span style={{ display: 'block', fontSize: '11px', color: 'var(--sky-light)', fontWeight: 700 }}>
                AI KRISHI ASSISTANT
              </span>
            </div>
          </div>
          <p>{t.footer.desc}</p>
        </div>

        <div className="footer-col">
          <h5>{t.footer.quickLinks}</h5>
          <ul>
            <li><a href="#features">{t.nav.features}</a></li>
            <li><a href="#crops">{t.nav.crops}</a></li>
            <li><a href="#how-it-works">{t.nav.howItWorks}</a></li>
            <li><a href="#pricing">{t.nav.pricing}</a></li>
            <li><a href="#reviews">{t.nav.reviews}</a></li>
          </ul>
        </div>

        <div className="footer-col">
          <h5>{t.footer.crops}</h5>
          <ul>
            <li><a href="#crops">लहसुन (Garlic)</a></li>
            <li><a href="#crops">अफीम (Opium Poppy)</a></li>
            <li><a href="#crops">गेहूँ (Wheat)</a></li>
            <li><a href="#crops">प्याज (Onion)</a></li>
            <li><a href="#crops">सरसों (Mustard)</a></li>
          </ul>
        </div>

        <div className="footer-col">
          <h5>{t.footer.legalTitle}</h5>
          <ul>
            <li><a href="/privacy-policy" target="_blank" rel="noreferrer">Privacy Policy</a></li>
            <li><a href="/terms-and-conditions" target="_blank" rel="noreferrer">Terms &amp; Conditions</a></li>
            <li><a href="/contact-us" target="_blank" rel="noreferrer">Contact &amp; Grievance</a></li>
            <li><a href="/account-deletion" target="_blank" rel="noreferrer">Account Deletion</a></li>
            <li><a href="/legal" target="_blank" rel="noreferrer">Legal Portal Hub</a></li>
          </ul>
        </div>
      </div>

      <div className="footer-bottom">
        <div>{t.footer.copyright}</div>
        <div style={{ color: 'var(--sky-ice)', fontSize: '12px' }}>
          Application ID: <code>com.agfarmer.app</code> • Android Native Vulkan Engine
        </div>
      </div>
    </footer>
  );
}
