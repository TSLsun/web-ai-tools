import { Squircle } from './IconSummary.jsx'

// iOS size matrix — order and context labels preserved from the spec sheet.
const SIZES = [
  { size: 180, ctx: ['Home @3×'] },
  { size: 152, ctx: ['iPad Home @2×'] },
  { size: 120, ctx: ['Home @2× /', 'Spotlight @3×'] },
  { size: 87, ctx: ['Settings @3×'] },
  { size: 80, ctx: ['Spotlight @2×'] },
  { divider: true },
  { size: 60, ctx: ['Home @1× /', 'Notif @3×'] },
  { size: 58, ctx: ['Settings @2×'] },
  { size: 40, ctx: ['Notif @2×'] },
]

export default function App() {
  return (
    <div className="page">

      {/* Header */}
      <header className="hd">
        <div>
          <h1>Summary</h1>
          <p className="sub">iOS App Icon · C-1 Masthead</p>
        </div>
        <div className="badge" role="status" aria-label="Direction locked, C-1">
          <svg width="11" height="11" viewBox="0 0 11 11" fill="none"
               aria-hidden="true" xmlns="http://www.w3.org/2000/svg">
            <circle cx="5.5" cy="5.5" r="5" stroke="#1044cc" strokeWidth="1" />
            <path d="M3.2 5.7L4.8 7.2L7.8 4" stroke="#1044cc" strokeWidth="1.3"
                  strokeLinecap="round" strokeLinejoin="round" />
          </svg>
          Direction locked · C-1
        </div>
      </header>

      {/* Hero: icon on contained light panel */}
      <div className="hero-panel" role="img" aria-label="Summary app icon, C-1 Masthead at 240px">
        <Squircle size={240}
          style={{ boxShadow: '0 16px 48px rgba(0,0,0,0.10), 0 0 0 1px rgba(0,0,0,0.06)' }} />
        <p className="hero-name">Summary · App Icon · Masthead</p>
      </div>

      {/* Dark wallpaper context: the actual environment */}
      <p className="dark-strip-label">On a dark wallpaper</p>
      <div className="dark-strip" role="img"
           aria-label="Icon previewed on dark wallpaper at Home screen and notification sizes">
        <div className="dark-si">
          <Squircle size={180} />
          <span className="dark-si-lbl">180px</span>
          <span className="dark-si-ctx">Home @3×</span>
        </div>
        <div className="dark-si">
          <Squircle size={60} />
          <span className="dark-si-lbl">60px</span>
          <span className="dark-si-ctx">Home @1×</span>
        </div>
      </div>

      {/* Size matrix */}
      <p className="sec">iOS Size Matrix</p>
      <div className="size-scroll" role="region" aria-label="Icon at all iOS required sizes">
        <div className="size-strip">
          {SIZES.map((item, i) =>
            item.divider ? (
              <div key={`d${i}`} className="si-divider" aria-hidden="true" />
            ) : (
              <div className="si" key={item.size}>
                <Squircle size={item.size} />
                <span className="si-px">{item.size}px</span>
                <span className="si-ctx">
                  {item.ctx.map((line, j) => (
                    <span key={j}>
                      {line}
                      {j < item.ctx.length - 1 && <br />}
                    </span>
                  ))}
                </span>
              </div>
            )
          )}
        </div>
      </div>

      {/* Spec */}
      <p className="sec">Design Specification</p>
      <div className="spec-grid">

        <div className="spec-card">
          <div className="spec-card-hd">
            <h3>Color</h3>
          </div>
          <div className="cr">
            <div className="swatch" style={{ background: '#f4f5fa' }} aria-hidden="true" />
            <div className="cr-info">
              <div className="cr-name">Background</div>
              <div className="cr-val">#f4f5fa · oklch(97% 0.008 254)</div>
            </div>
            <span className="cr-role">Canvas</span>
          </div>
          <div className="cr">
            <div className="swatch" style={{ background: '#1044cc' }} aria-hidden="true" />
            <div className="cr-info">
              <div className="cr-name">Cobalt</div>
              <div className="cr-val">#1044cc · oklch(44% 0.19 256)</div>
            </div>
            <span className="cr-role">Primary rule</span>
          </div>
          <div className="cr">
            <div className="swatch" style={{ background: '#f4f5fa' }} aria-hidden="true">
              {/* Overlay to simulate cobalt 30% on canvas bg */}
              <div style={{ width: '100%', height: '100%', background: 'rgba(16,68,204,0.3)', borderRadius: '5px' }} />
            </div>
            <div className="cr-info">
              <div className="cr-name">Cobalt 30%</div>
              <div className="cr-val">#1044cc · opacity 0.30</div>
            </div>
            <span className="cr-role">Ghost rule</span>
          </div>
          <div className="cr">
            <div className="swatch" style={{ background: '#09111f' }} aria-hidden="true" />
            <div className="cr-info">
              <div className="cr-name">Ink</div>
              <div className="cr-val">#09111f · oklch(13% 0.02 256)</div>
            </div>
            <span className="cr-role">Lettermark</span>
          </div>
        </div>

        <div className="spec-card">
          <div className="spec-card-hd">
            <h3>Measurements</h3>
            <p className="spec-sub">100 × 100 SVG coordinate space</p>
          </div>
          <div className="mr"><span className="mr-lbl">Canvas</span><span className="mr-val">100 × 100 u</span></div>
          <div className="mr"><span className="mr-lbl">Primary rule · origin</span><span className="mr-val">x 24, y 14</span></div>
          <div className="mr"><span className="mr-lbl">Primary rule · size</span><span className="mr-val">52 × 4.5 u, rx 2.25</span></div>
          <div className="mr"><span className="mr-lbl">Ghost rule · origin</span><span className="mr-val">x 24, y 22.5</span></div>
          <div className="mr"><span className="mr-lbl">Ghost rule · size</span><span className="mr-val">34 × 2.5 u, rx 1.25</span></div>
          <div className="mr"><span className="mr-lbl">Lettermark · anchor</span><span className="mr-val">cx 50, y 82</span></div>
          <div className="mr"><span className="mr-lbl">Lettermark · typeface</span><span className="mr-val">SF Pro Display 800</span></div>
          <div className="mr"><span className="mr-lbl">Lettermark · size</span><span className="mr-val">70 u · −0.03em</span></div>
          <div className="mr"><span className="mr-lbl">Squircle mask</span><span className="mr-val">border-radius 22.5%</span></div>
        </div>

      </div>

      <aside className="note" role="note">
        <strong>Before shipping to App Store:</strong> replace the SVG <code>&lt;text&gt;</code>{' '}
        element with an outlined path of the S letterform in SF Pro Display ExtraBold — font
        rendering varies across renderers and Apple's validator expects all text as outlines.
        Master export at <strong>1024×1024 px</strong> (no rounded corners — Xcode applies the mask).
      </aside>

    </div>
  )
}
