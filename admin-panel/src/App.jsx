import { useEffect, useState } from 'react';
import { API, ENV_KEY, call } from './api.js';
import { Field, Banner } from './ui.jsx';
import LimitsTab from './tabs/LimitsTab.jsx';
import PlansTab from './tabs/PlansTab.jsx';
import CropsTab from './tabs/CropsTab.jsx';
import UsersTab from './tabs/UsersTab.jsx';
import SupportTab from './tabs/SupportTab.jsx';
import AnnounceTab from './tabs/AnnounceTab.jsx';
import CreditsTab from './tabs/CreditsTab.jsx';
import ServerTab from './tabs/ServerTab.jsx';

const TABS = [
  ['limits', 'लिमिट / शॉट'],
  ['plans', 'प्लान'],
  ['crops', 'फसल'],
  ['users', 'यूज़र / गेस्ट'],
  ['support', 'सपोर्ट'],
  ['announce', 'घोषणा'],
  ['credits', 'टोकन'],
  ['server', 'सर्वर'],
];

export default function App() {
  const [api] = useState(API);
  const [key, setKey] = useState(ENV_KEY);
  const [ready, setReady] = useState(false);
  const [tab, setTab] = useState('limits');
  const [limits, setLimits] = useState(null);
  const [catalog, setCatalog] = useState({ plans: {}, crops: {} });
  const [people, setPeople] = useState([]);
  const [peopleCounts, setPeopleCounts] = useState({ users: 0, guests: 0, online: 0 });
  const [requests, setRequests] = useState({});
  const [announces, setAnnounces] = useState([]);
  const [annCrop, setAnnCrop] = useState('afim');
  const [annTitle, setAnnTitle] = useState('');
  const [annBody, setAnnBody] = useState('');
  const [tokenVoice, setTokenVoice] = useState('5');
  const [tokenVideo, setTokenVideo] = useState('1');
  const [madeCode, setMadeCode] = useState('');
  const [tokenRows, setTokenRows] = useState([]);
  const [metrics, setMetrics] = useState(null);
  const [analytics, setAnalytics] = useState(null);
  const [system, setSystem] = useState(null);
  const [error, setError] = useState('');
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (key) load();
  }, []);

  async function load(nextKey = key) {
    setBusy(true);
    setError('');
    try {
      const body = await call(api, nextKey, 'admin.chat.limits.get');
      setLimits(body.limits);
      sessionStorage.setItem('ag_admin_key', nextKey);
      setReady(true);
      const extras = await Promise.allSettled([
        call(api, nextKey, 'admin.catalog.get'),
        call(api, nextKey, 'announcement.list'),
        call(api, nextKey, 'admin.people.list', { limit: 150 }),
        call(api, nextKey, 'admin.support.list'),
        call(api, nextKey, 'admin.credit.list'),
        call(api, nextKey, 'admin.metrics'),
        call(api, nextKey, 'admin.analytics.get'),
        call(api, nextKey, 'admin.system.get'),
      ]);
      if (extras[0].status === 'fulfilled') setCatalog(extras[0].value);
      if (extras[1].status === 'fulfilled') setAnnounces(extras[1].value.posts || []);
      if (extras[2].status === 'fulfilled') {
        setPeople(extras[2].value.people || []);
        setPeopleCounts(extras[2].value.counts || { users: 0, guests: 0, online: 0 });
      }
      if (extras[3].status === 'fulfilled') setRequests(extras[3].value.requests || {});
      if (extras[4].status === 'fulfilled') setTokenRows(extras[4].value.tokens || []);
      if (extras[5].status === 'fulfilled') setMetrics(extras[5].value.metrics || null);
      if (extras[6].status === 'fulfilled') setAnalytics(extras[6].value.analytics || null);
      if (extras[7].status === 'fulfilled') setSystem(extras[7].value);
    } catch (e) {
      setReady(false);
      setError(e.message);
    } finally {
      setBusy(false);
    }
  }

  async function saveLimits() {
    setBusy(true);
    setError('');
    setNote('');
    try {
      const body = await call(api, key, 'admin.chat.limits.set', { limits });
      setLimits(body.limits);
      setNote('लिमिट सेव। अगली चैट से नई वैल्यू चलेगी।');
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  }

  async function savePlans() {
    setBusy(true);
    setError('');
    setNote('');
    try {
      const plans = await call(api, key, 'admin.catalog.plans.set', { plans: catalog.plans });
      setCatalog((prev) => ({
        ...prev,
        plans: plans.plans || prev.plans,
      }));
      setNote('प्लान सेव। ऐप नई कैटलॉग लेगा।');
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  }

  async function saveCrops() {
    setBusy(true);
    setError('');
    setNote('');
    try {
      const body = await call(api, key, 'admin.catalog.crops.set', { crops: catalog.crops });
      setCatalog((prev) => ({ ...prev, crops: body.crops || prev.crops }));
      setNote('फसल सेव।');
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  }

  async function reloadUsers() {
    const body = await call(api, key, 'admin.people.list', { limit: 150 });
    setPeople(body.people || []);
    setPeopleCounts(body.counts || { users: 0, guests: 0, online: 0 });
  }

  if (!ready || !limits) {
    return (
      <main className="app">
        <h1>AG Farmer Admin</h1>
        <p className="sub">लोकल पैनल। APK के शॉट, कोटा, प्लान, फसल — सब यहीं। वेबसाइट पर /admin नहीं खुलता।</p>
        <section className="card">
          <div className="row">
            <Field label="एडमिन की" type="password" value={key} onChange={setKey} />
          </div>
          <div className="actions" style={{ marginTop: 14 }}>
            <button className="primary" disabled={busy} onClick={() => load()}>
              {busy ? 'खुल रहा है…' : 'पैनल खोलो'}
            </button>
            {error ? <p className="err" role="alert">{error}</p> : null}
          </div>
        </section>
      </main>
    );
  }

  return (
    <main className="app">
      <header className="top">
        <div>
          <h1>AG Farmer Admin</h1>
          <p className="sub">लोकल कंट्रोल। APK बदलने की जरूरत नहीं।</p>
        </div>
        <button
          className="ghost"
          onClick={() => {
            sessionStorage.removeItem('ag_admin_key');
            setKey('');
            setReady(false);
          }}
        >
          बाहर जाओ
        </button>
      </header>

      <nav className="tabs">
        {TABS.map(([id, label]) => (
          <button key={id} className={tab === id ? 'tab on' : 'tab'} onClick={() => setTab(id)}>
            {label}
          </button>
        ))}
      </nav>

      {tab === 'limits' ? <LimitsTab limits={limits} setLimits={setLimits} onSave={saveLimits} busy={busy} /> : null}
      {tab === 'plans' ? <PlansTab catalog={catalog} setCatalog={setCatalog} onSave={savePlans} busy={busy} /> : null}
      {tab === 'crops' ? <CropsTab catalog={catalog} setCatalog={setCatalog} onSave={saveCrops} busy={busy} /> : null}
      {tab === 'users' ? (
        <UsersTab
          api={api}
          adminKey={key}
          people={people}
          counts={peopleCounts}
          reloadUsers={reloadUsers}
          busy={busy}
          setBusy={setBusy}
          setError={setError}
          setNote={setNote}
        />
      ) : null}
      {tab === 'support' ? (
        <SupportTab
          api={api}
          adminKey={key}
          requests={requests}
          setRequests={setRequests}
          busy={busy}
          setBusy={setBusy}
          setError={setError}
          setNote={setNote}
        />
      ) : null}
      {tab === 'announce' ? (
        <AnnounceTab
          api={api}
          adminKey={key}
          announces={announces}
          setAnnounces={setAnnounces}
          crop={annCrop}
          setCrop={setAnnCrop}
          title={annTitle}
          setTitle={setAnnTitle}
          body={annBody}
          setBody={setAnnBody}
          busy={busy}
          setBusy={setBusy}
          setError={setError}
          setNote={setNote}
        />
      ) : null}
      {tab === 'credits' ? (
        <CreditsTab
          api={api}
          adminKey={key}
          tokenVoice={tokenVoice}
          setTokenVoice={setTokenVoice}
          tokenVideo={tokenVideo}
          setTokenVideo={setTokenVideo}
          madeCode={madeCode}
          setMadeCode={setMadeCode}
          tokenRows={tokenRows}
          setTokenRows={setTokenRows}
          busy={busy}
          setBusy={setBusy}
          setError={setError}
        />
      ) : null}
      {tab === 'server' ? <ServerTab metrics={metrics} analytics={analytics} system={system} /> : null}

      <div className="actions sticky">
        <Banner note={note} error={error} />
      </div>
    </main>
  );
}
