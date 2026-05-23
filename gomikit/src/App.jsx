import { useMemo, useState } from 'react'
import {
  AlertTriangle,
  Bell,
  Building2,
  CalendarDays,
  CheckCircle2,
  ChevronDown,
  Clock3,
  Database,
  ExternalLink,
  Home,
  Languages,
  MapPin,
  QrCode,
  Recycle,
  Search,
  ShieldCheck,
  Sparkles,
  Trash2,
  Upload,
} from 'lucide-react'
import { QRCodeSVG } from 'qrcode.react'
import {
  areas,
  areaText,
  cultureTips,
  cultureTipsText,
  languageLabels,
  officialSources,
  officialSourceText,
  qrPageProfiles,
  uiText,
  wasteRuleText,
  wasteRules,
} from './data'
import './App.css'

function App() {
  const publicQrRequest = parsePublicQrPath(window.location.pathname)

  if (publicQrRequest) {
    return <PublicQrPage areaId={publicQrRequest.areaId} mode={publicQrRequest.mode} />
  }

  return <DashboardApp />
}

function DashboardApp() {
  const [areaId, setAreaId] = useState('shibuya')
  const [query, setQuery] = useState('')
  const [language, setLanguage] = useState('zh')
  const [selectedRuleId, setSelectedRuleId] = useState('pet-bottle')
  const [reminderEnabled, setReminderEnabled] = useState(true)
  const [qrMode, setQrMode] = useState('guest')
  const [toast, setToast] = useState(null)

  const t = uiText[language] ?? uiText.zh
  const area = localizeArea(areas.find((item) => item.id === areaId), language)
  const selectedRule = localizeRule(wasteRules.find((rule) => rule.id === selectedRuleId), language)
  const todayRules = wasteRules
    .filter((rule) => rule.days[areaId].includes('周') || rule.days[areaId].includes('曜'))
    .map((rule) => localizeRule(rule, language))

  const filteredRules = useMemo(() => {
    const normalizedQuery = query.trim().toLowerCase()
    if (!normalizedQuery) return wasteRules.map((rule) => localizeRule(rule, language))

    return wasteRules.filter((rule) => {
      const localizedRule = localizeRule(rule, language)
      const haystack = [
        rule.name,
        rule.type,
        ...rule.aliases,
        localizedRule.name,
        localizedRule.type,
        ...localizedRule.aliases,
      ].join(' ').toLowerCase()
      return haystack.includes(normalizedQuery)
    }).map((rule) => localizeRule(rule, language))
  }, [language, query])

  const activeSource = localizeSource(officialSources.find((source) => source.area === areaId), language)
  const qrUrl = `${window.location.origin}/q/${areaId}-${qrMode}?lang=${language}`
  const qrProfile = qrPageProfiles[qrMode]
  const qrCopy = qrProfile.i18n?.[language] ?? qrProfile
  const localizedCultureTips = cultureTipsText[language] ?? cultureTips

  const applyManagedRule = (rule) => {
    setSelectedRuleId(rule.id)
    setQuery('')
    const toastId = crypto.randomUUID()
    setToast({ id: toastId, message: t.appliedToast(localizeRule(rule, language).name) })
    window.setTimeout(() => {
      setToast((current) => (current?.id === toastId ? null : current))
    }, 1600)
  }

  return (
    <main className="app-shell">
      <aside className="sidebar" aria-label="主导航">
        <div className="brand">
          <div className="brand-mark">
            <Recycle size={24} aria-hidden="true" />
          </div>
          <div>
            <strong>GomiKit</strong>
            <span>{t.appSubtitle}</span>
          </div>
        </div>

        <nav className="nav-list">
          <a href="#today" className="nav-item active">
            <Home size={18} aria-hidden="true" />
            {t.navToday}
          </a>
          <a href="#search" className="nav-item">
            <Search size={18} aria-hidden="true" />
            {t.navSearch}
          </a>
          <a href="#qr" className="nav-item">
            <QrCode size={18} aria-hidden="true" />
            {t.navQr}
          </a>
          <a href="#management" className="nav-item">
            <Database size={18} aria-hidden="true" />
            {t.navManagement}
          </a>
          <a href="#sources" className="nav-item">
            <ShieldCheck size={18} aria-hidden="true" />
            {t.navSources}
          </a>
        </nav>

        <section className="sidebar-panel">
          <div className="tiny-label">{t.defaultReminder}</div>
          <button
            className={`toggle-row ${reminderEnabled ? 'enabled' : ''}`}
            type="button"
            onClick={() => setReminderEnabled((current) => !current)}
            aria-pressed={reminderEnabled}
          >
            <Bell size={18} aria-hidden="true" />
            {t.reminderTime}
            <span>{reminderEnabled ? t.on : t.off}</span>
          </button>
        </section>
      </aside>

      <section className="workspace">
        <header className="topbar">
          <div>
            <p className="eyebrow">{t.heroEyebrow}</p>
            <h1>{t.heroTitle}</h1>
          </div>
          <div className="topbar-controls">
            <label className="select-field">
              <MapPin size={17} aria-hidden="true" />
              <select value={areaId} onChange={(event) => setAreaId(event.target.value)}>
                {areas.map((item) => {
                  const optionArea = localizeArea(item, language)
                  return (
                  <option key={item.id} value={item.id}>
                    {optionArea.name}
                  </option>
                  )
                })}
              </select>
              <ChevronDown size={16} aria-hidden="true" />
            </label>
            <label className="select-field compact">
              <Languages size={17} aria-hidden="true" />
              <select value={language} onChange={(event) => setLanguage(event.target.value)}>
                {Object.entries(languageLabels).map(([key, label]) => (
                  <option key={key} value={key}>
                    {label}
                  </option>
                ))}
              </select>
              <ChevronDown size={16} aria-hidden="true" />
            </label>
          </div>
        </header>

        <section id="today" className="dashboard-grid">
          <article className="today-panel">
            <div className="section-heading">
              <div>
                <p className="eyebrow">{t.currentLocation}</p>
                <h2>{area.name}</h2>
              </div>
              <span className="status-pill">
                <CheckCircle2 size={16} aria-hidden="true" />
                {t.officialConfirmed}
              </span>
            </div>

            <div className="location-strip">
              <MapPin size={20} aria-hidden="true" />
              <div>
                <strong>{area.neighborhood}</strong>
                <span>{area.ward} · {t.autoLocated}</span>
              </div>
            </div>

            <div className="today-list">
              {todayRules.slice(0, 3).map((rule) => (
                <button
                  className={`waste-card ${selectedRuleId === rule.id ? 'selected' : ''}`}
                  key={rule.id}
                  type="button"
                  onClick={() => setSelectedRuleId(rule.id)}
                >
                  <span className="waste-icon">{rule.icon}</span>
                  <span>
                    <strong>{rule.name}</strong>
                    <small>{rule.type} · {rule.days[areaId]}</small>
                  </span>
                </button>
              ))}
            </div>
          </article>

          <article className="reminder-panel">
            <div className="section-heading">
              <div>
                <p className="eyebrow">{t.notification}</p>
                <h2>{t.reminderTitle}</h2>
              </div>
              <Bell size={22} aria-hidden="true" />
            </div>
            <div className="reminder-time">
              <Clock3 size={22} aria-hidden="true" />
              <strong>21:00</strong>
              <span>{languageLabels[language]} {t.pushLabel}</span>
            </div>
            <p className="muted">{t.reminderSentence(selectedRule)}</p>
          </article>

          <article className="source-panel">
            <div className="section-heading">
              <div>
                <p className="eyebrow">{t.navSources}</p>
                <h2>{t.trustedData}</h2>
              </div>
              <ExternalLink size={21} aria-hidden="true" />
            </div>
            <p>{activeSource.label}</p>
            <span>{activeSource.freshness} · {t.dataUpdatedAt} {area.sourceUpdatedAt}</span>
          </article>
        </section>

        <section id="search" className="content-grid">
          <article className="search-panel">
            <div className="section-heading">
              <div>
                <p className="eyebrow">{t.searchEyebrow}</p>
                <h2>{t.searchTitle}</h2>
              </div>
              <Search size={22} aria-hidden="true" />
            </div>
            <label className="search-box">
              <Search size={20} aria-hidden="true" />
              <input
                value={query}
                onChange={(event) => setQuery(event.target.value)}
                placeholder={t.searchPlaceholder}
              />
            </label>

            <div className="result-list">
              {filteredRules.map((rule) => (
                <button
                  key={rule.id}
                  type="button"
                  className={`result-row ${selectedRuleId === rule.id ? 'active' : ''}`}
                  onClick={() => setSelectedRuleId(rule.id)}
                >
                  <span className="waste-icon small">{rule.icon}</span>
                  <span>
                    <strong>{rule.name}</strong>
                    <small>{rule.aliases.join(' / ')}</small>
                  </span>
                  <em>{rule.type}</em>
                </button>
              ))}
            </div>
          </article>

          <article className="detail-panel">
            <div className="section-heading">
              <div>
                <p className="eyebrow">{t.disposalInstructions}</p>
                <h2>{selectedRule.name}</h2>
              </div>
              <span className="category-badge">{selectedRule.type}</span>
            </div>

            <div className="instruction-grid">
              <InfoItem icon={<Sparkles size={18} />} label={t.wash} value={selectedRule.wash} />
              <InfoItem icon={<Recycle size={18} />} label={t.label} value={selectedRule.label} />
              <InfoItem icon={<Recycle size={18} />} label={t.cap} value={selectedRule.cap} />
              <InfoItem icon={<CalendarDays size={18} />} label={t.collectionDay} value={selectedRule.days[areaId]} />
              <InfoItem icon={<Clock3 size={18} />} label={t.disposalTime} value={selectedRule.time} />
              <InfoItem icon={<MapPin size={18} />} label={t.place} value={selectedRule.location} />
            </div>

            <ol className="steps-list">
              {selectedRule.steps.map((step) => (
                <li key={step}>{step}</li>
              ))}
            </ol>

            <div className="warning-box">
              <AlertTriangle size={20} aria-hidden="true" />
              <span>{selectedRule.caution}</span>
            </div>
          </article>
        </section>

        <section id="management" className="management-section">
          <article className="management-panel">
            <div className="section-heading">
              <div>
                <p className="eyebrow">{t.management}</p>
                <h2>{t.commonWasteItems}</h2>
              </div>
              <Database size={22} aria-hidden="true" />
            </div>
            <div className="managed-list">
              {wasteRules.map((rule) => {
                const managedRule = localizeRule(rule, language)
                return (
                <div className="managed-row" key={managedRule.id}>
                  <span className="waste-icon small">{managedRule.icon}</span>
                  <div className="managed-row-main">
                    <strong>{managedRule.name}</strong>
                    <small>{managedRule.type} · {managedRule.aliases.join(' / ')}</small>
                  </div>
                  <button type="button" onClick={() => applyManagedRule(rule)}>
                    {t.use}
                  </button>
                  <button type="button" className="icon-action" aria-label={`${t.delete} ${managedRule.name}`}>
                    <Trash2 size={18} aria-hidden="true" />
                  </button>
                </div>
                )
              })}
            </div>
          </article>

          <article className="management-panel">
            <div className="section-heading">
              <div>
                <p className="eyebrow">{t.reuseStatus}</p>
                <h2>{t.currentGuide}</h2>
              </div>
              <CheckCircle2 size={22} aria-hidden="true" />
            </div>
            <div className="selected-managed-rule">
              <span className="waste-icon">{selectedRule.icon}</span>
              <div>
                <strong>{selectedRule.name}</strong>
                <small>{selectedRule.type} · {selectedRule.days[areaId]}</small>
              </div>
            </div>
            <p className="muted">{t.managementNote}</p>
          </article>
        </section>

        <section id="qr" className="qr-section">
          <article className="qr-builder">
            <div className="section-heading">
              <div>
                <p className="eyebrow">{t.qrPage}</p>
                <h2>{t.qrTitle}</h2>
              </div>
              <Building2 size={22} aria-hidden="true" />
            </div>
            <div className="segmented-control" aria-label="QR 页面类型">
              {['guest', 'shop', 'multi'].map((mode) => (
                <button
                  key={mode}
                  type="button"
                  className={qrMode === mode ? 'selected' : ''}
                  onClick={() => setQrMode(mode)}
                >
                  {mode === 'guest' ? t.guestMode : mode === 'shop' ? t.shopMode : t.multiMode}
                </button>
              ))}
            </div>

            <div className="upload-strip">
              <Upload size={20} aria-hidden="true" />
              <div>
                <strong>{t.photoUpload}</strong>
                <span>{t.photoUploadNote}</span>
              </div>
            </div>

            <div className="poster-actions">
              <a href={qrUrl} target="_blank" rel="noreferrer">
                <QrCode size={18} aria-hidden="true" />
                {t.openPublicPage}
              </a>
              <button type="button">
                <ExternalLink size={18} aria-hidden="true" />
                {t.posterPdf}
              </button>
            </div>
          </article>

          <article className="qr-preview">
            <div className="phone-frame" aria-label="公开 QR 页面预览">
              <div className="phone-header">
                <span>{qrProfile.owner}</span>
                <strong>{qrCopy.title}</strong>
              </div>
              <div className="qr-code-box">
                <QRCodeSVG value={qrUrl} size={128} />
              </div>
              <p>{qrUrl}</p>
              <div className="guest-note">
                <MapPin size={16} aria-hidden="true" />
                <span>{area.collectionPoint}</span>
              </div>
              <div className="guest-rule">
                <span className="waste-icon small">{selectedRule.icon}</span>
                <div>
                  <strong>{selectedRule.name}</strong>
                  <small>{selectedRule.time} · {selectedRule.location}</small>
                </div>
              </div>
              <div className="guest-note">
                <Languages size={16} aria-hidden="true" />
                <span>{languageLabels[language]} · {qrCopy.note}</span>
              </div>
            </div>
          </article>
        </section>

        <section id="sources" className="bottom-grid">
          <article>
            <p className="eyebrow">{t.ingestionEyebrow}</p>
            <h2>{t.ingestionTitle}</h2>
            <div className="pipeline">
              {t.ingestionSteps.map((step) => (
                <span key={step}>{step}</span>
              ))}
            </div>
          </article>
          <article>
            <p className="eyebrow">{t.cultureEyebrow}</p>
            <h2>{t.cultureTitle}</h2>
            <ul className="tip-list">
              {localizedCultureTips.map((tip) => (
                <li key={tip}>{tip}</li>
              ))}
            </ul>
          </article>
        </section>
      </section>

      {toast && (
        <div className="toast" role="status" aria-live="polite">
          <CheckCircle2 size={18} aria-hidden="true" />
          {toast.message}
        </div>
      )}
    </main>
  )
}

function PublicQrPage({ areaId, mode }) {
  const profile = qrPageProfiles[mode] ?? qrPageProfiles.guest
  const language = new URLSearchParams(window.location.search).get('lang') ?? 'zh'
  const t = uiText[language] ?? uiText.zh
  const area = localizeArea(areas.find((item) => item.id === areaId) ?? areas[0], language)
  const todayRules = wasteRules
    .filter((rule) => rule.days[area.id].includes('周') || rule.days[area.id].includes('曜'))
    .slice(0, 3)
    .map((rule) => localizeRule(rule, language))
  const profileCopy = profile.i18n?.[language] ?? profile

  return (
    <main className="public-page">
      <section className="public-hero">
        <div className="brand public-brand">
          <div className="brand-mark">
            <Recycle size={24} aria-hidden="true" />
          </div>
          <div>
            <strong>GomiKit</strong>
            <span>{profile.owner}</span>
          </div>
        </div>
        <a className="back-link" href="/">
          <Home size={17} aria-hidden="true" />
          {t.admin}
        </a>
      </section>

      <section className="public-layout">
        <article className="public-card lead">
          <p className="eyebrow">{t.publicQrPage}</p>
          <h1>{profileCopy.title}</h1>
          <p>{profileCopy.note}</p>
          <div className="public-location">
            <MapPin size={20} aria-hidden="true" />
            <div>
              <strong>{area.name} · {area.neighborhood}</strong>
              <span>{area.collectionPoint}</span>
            </div>
          </div>
        </article>

        <article className="public-card">
          <div className="section-heading">
            <div>
              <p className="eyebrow">{t.todayCanDispose}</p>
              <h2>{t.todayWaste}</h2>
            </div>
            <CalendarDays size={22} aria-hidden="true" />
          </div>
          <div className="public-rule-list">
            {todayRules.map((rule) => (
              <div className="public-rule" key={rule.id}>
                <span className="waste-icon small">{rule.icon}</span>
                <div>
                  <strong>{rule.name}</strong>
                  <small>{rule.type} · {rule.days[area.id]} · {rule.time}</small>
                </div>
              </div>
            ))}
          </div>
        </article>

        <article className="public-card">
          <div className="section-heading">
            <div>
              <p className="eyebrow">{t.beforeDisposal}</p>
              <h2>{t.basicRules}</h2>
            </div>
            <ShieldCheck size={22} aria-hidden="true" />
          </div>
          <ul className="public-checks">
            {t.publicRules.map((rule) => (
              <li key={rule}>{rule}</li>
            ))}
          </ul>
        </article>

        <article className="public-card source-panel">
          <div className="section-heading">
            <div>
              <p className="eyebrow">{t.navSources}</p>
              <h2>{t.ruleUpdatedAt}</h2>
            </div>
            <ExternalLink size={21} aria-hidden="true" />
          </div>
          <p>{localizeSource(officialSources.find((source) => source.area === area.id), language)?.label}</p>
          <span>{t.dataUpdatedAt} {area.sourceUpdatedAt}</span>
        </article>
      </section>
    </main>
  )
}

function localizeArea(area, language) {
  if (!area) return areas[0]
  const text = areaText[area.id]?.[language]
  return text ? { ...area, ...text } : area
}

function localizeRule(rule, language) {
  if (!rule) return wasteRules[0]
  const text = wasteRuleText[rule.id]?.[language]
  return text ? { ...rule, ...text } : rule
}

function localizeSource(source, language) {
  if (!source) return officialSources[0]
  const text = officialSourceText[source.area]?.[language]
  return text ? { ...source, ...text } : source
}

function parsePublicQrPath(pathname) {
  const match = pathname.match(/^\/q\/([a-z-]+)-(guest|shop|multi)$/)
  if (!match) return null

  return {
    areaId: match[1],
    mode: match[2],
  }
}

function InfoItem({ icon, label, value }) {
  return (
    <div className="info-item">
      <span>{icon}</span>
      <div>
        <small>{label}</small>
        <strong>{value}</strong>
      </div>
    </div>
  )
}

export default App
