// Summary app icon — C-1 Masthead artwork (the "#c1" group from the source spec).
// Rendered inline so every Squircle reuses identical vector art at any size.
export function IconArt() {
  return (
    <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
      <rect width="100" height="100" fill="#f4f5fa" />
      <rect x="24" y="14" width="52" height="4.5" rx="2.25" fill="#1044cc" />
      <rect x="24" y="22.5" width="34" height="2.5" rx="1.25" fill="#1044cc" opacity="0.3" />
      <text
        x="50"
        y="82"
        textAnchor="middle"
        fontFamily="system-ui,-apple-system,'SF Pro Display',sans-serif"
        fontWeight="800"
        fontSize="70"
        fill="#09111f"
        style={{ letterSpacing: '-0.03em' }}
      >
        S
      </text>
    </svg>
  )
}

// Squircle-masked tile. `size` maps to the .sq-<n> CSS classes.
export function Squircle({ size, style }) {
  return (
    <div className={`sq sq-${size}`} style={style}>
      <IconArt />
    </div>
  )
}
