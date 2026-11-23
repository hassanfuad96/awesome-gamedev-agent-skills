// Renders the Grow a Reef icon and thumbnails as original vector art.
// Usage: node render.js <outDir>
// Needs Node and Playwright (npm i playwright; npx playwright install chromium).
const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

const outDir = process.argv[2] || '.';

// Seeded random so every render is identical.
let seed = 7;
const rand = () => ((seed = (seed * 16807) % 2147483647) / 2147483647);
const r = (a, b) => a + rand() * (b - a);

// ---------- shared defs ----------
const defs = `
<defs>
  <linearGradient id="water" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#3fd0e8"/>
    <stop offset="0.35" stop-color="#1688b8"/>
    <stop offset="1" stop-color="#062a55"/>
  </linearGradient>
  <linearGradient id="nightWater" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#1a3c7a"/>
    <stop offset="1" stop-color="#030b24"/>
  </linearGradient>
  <linearGradient id="ray" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#ffffff" stop-opacity="0.45"/>
    <stop offset="1" stop-color="#ffffff" stop-opacity="0"/>
  </linearGradient>
  <linearGradient id="sand" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#f3dca0"/>
    <stop offset="1" stop-color="#c99a5b"/>
  </linearGradient>
  <radialGradient id="bubble" cx="0.35" cy="0.3" r="0.7">
    <stop offset="0" stop-color="#ffffff" stop-opacity="0.95"/>
    <stop offset="0.25" stop-color="#ffffff" stop-opacity="0.25"/>
    <stop offset="1" stop-color="#bff6ff" stop-opacity="0.1"/>
  </radialGradient>
  <radialGradient id="pearl" cx="0.35" cy="0.3" r="0.8">
    <stop offset="0" stop-color="#ffffff"/>
    <stop offset="0.6" stop-color="#f4ecff"/>
    <stop offset="1" stop-color="#c9b8e8"/>
  </radialGradient>
  <radialGradient id="glow" cx="0.5" cy="0.5" r="0.5">
    <stop offset="0" stop-color="#fff6b0" stop-opacity="0.9"/>
    <stop offset="1" stop-color="#ffd84a" stop-opacity="0"/>
  </radialGradient>
  <radialGradient id="cyanGlow" cx="0.5" cy="0.5" r="0.5">
    <stop offset="0" stop-color="#9ffcff" stop-opacity="0.8"/>
    <stop offset="1" stop-color="#3ee6f0" stop-opacity="0"/>
  </radialGradient>
  <linearGradient id="gold" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#fff3a6"/>
    <stop offset="0.5" stop-color="#ffc21a"/>
    <stop offset="1" stop-color="#c77a00"/>
  </linearGradient>
  <linearGradient id="prism" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#ff7ad9"/>
    <stop offset="0.25" stop-color="#ffd25e"/>
    <stop offset="0.5" stop-color="#7dffb0"/>
    <stop offset="0.75" stop-color="#6ad8ff"/>
    <stop offset="1" stop-color="#b07dff"/>
  </linearGradient>
  <filter id="soft" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="6"/></filter>
  <filter id="shadow" x="-20%" y="-20%" width="140%" height="160%">
    <feDropShadow dx="0" dy="8" stdDeviation="6" flood-color="#021633" flood-opacity="0.55"/>
  </filter>
</defs>`;

// ---------- components ----------
function rays(w, h, n, opacity = 1) {
  let s = `<g opacity="${opacity}">`;
  for (let i = 0; i < n; i++) {
    const x = r(-0.1, 1.0) * w, top = r(0.04, 0.12) * w, bottom = top * r(2.5, 4);
    const lean = r(-0.15, 0.25) * w;
    s += `<polygon points="${x},0 ${x + top},0 ${x + lean + bottom},${h} ${x + lean},${h}" fill="url(#ray)" opacity="${r(0.25, 0.6)}"/>`;
  }
  return s + '</g>';
}

function bubbles(w, h, n, minR, maxR) {
  let s = '';
  for (let i = 0; i < n; i++) {
    const rr = r(minR, maxR);
    s += `<circle cx="${r(0, w)}" cy="${r(0, h)}" r="${rr}" fill="url(#bubble)" stroke="#e8fdff" stroke-opacity="0.7" stroke-width="${Math.max(1, rr * 0.08)}"/>`;
  }
  return s;
}

function seabed(w, h, y) {
  let d = `M0 ${y}`;
  const steps = 8;
  for (let i = 1; i <= steps; i++) {
    const x = (i / steps) * w;
    d += ` Q ${x - w / steps / 2} ${y + r(-0.04, 0.04) * h} ${x} ${y + r(-0.02, 0.02) * h}`;
  }
  d += ` L ${w} ${h} L 0 ${h} Z`;
  let s = `<path d="${d}" fill="url(#sand)"/>`;
  for (let i = 0; i < 40; i++) {
    s += `<ellipse cx="${r(0, w)}" cy="${r(y + 0.04 * h, h)}" rx="${r(2, 6)}" ry="${r(1, 3)}" fill="#b98a4f" opacity="0.5"/>`;
  }
  return s;
}

function kelp(x, y, height, scale, color = '#4fc65a') {
  let s = '';
  for (let k = 0; k < 3; k++) {
    const ox = x + (k - 1) * 18 * scale;
    const hh = height * (0.75 + k * 0.15);
    const sway = (k - 1) * 25 * scale;
    s += `<path d="M${ox} ${y} C ${ox - 30 * scale} ${y - hh * 0.35}, ${ox + 35 * scale + sway} ${y - hh * 0.65}, ${ox + sway} ${y - hh}" stroke="${color}" stroke-width="${12 * scale}" fill="none" stroke-linecap="round"/>`;
    // leaves and gas bubbles
    for (let l = 1; l <= 3; l++) {
      const t = l / 4;
      const lx = ox + sway * t + (l % 2 ? 14 : -14) * scale;
      const ly = y - hh * t;
      s += `<ellipse cx="${lx}" cy="${ly}" rx="${16 * scale}" ry="${6 * scale}" fill="${color}" transform="rotate(${l % 2 ? -30 : 30} ${lx} ${ly})"/>`;
    }
    s += `<circle cx="${ox + sway}" cy="${y - hh}" r="${9 * scale}" fill="#b9f5a8" stroke="${color}" stroke-width="${3 * scale}"/>`;
  }
  return s;
}

function brainCoral(x, y, size, fill = '#f27fa3', line = '#c84b78') {
  let s = `<g filter="url(#shadow)"><ellipse cx="${x}" cy="${y - size * 0.45}" rx="${size}" ry="${size * 0.75}" fill="${fill}"/>`;
  for (let i = -2; i <= 2; i++) {
    const yy = y - size * 0.45 + i * size * 0.22;
    const half = size * Math.sqrt(Math.max(0, 1 - (i * 0.3) ** 2)) * 0.8;
    s += `<path d="M${x - half} ${yy} q ${half / 4} -${size * 0.12} ${half / 2} 0 t ${half / 2} 0 t ${half / 2} 0 t ${half / 2} 0" stroke="${line}" stroke-width="${size * 0.05}" fill="none" stroke-linecap="round"/>`;
  }
  return s + '</g>';
}

function seaFan(x, y, size, color = '#a066e6') {
  let s = `<g filter="url(#shadow)">`;
  s += `<path d="M${x} ${y} L ${x} ${y - size * 0.3}" stroke="#6b3da8" stroke-width="${size * 0.08}" stroke-linecap="round"/>`;
  const branch = (bx, by, angle, len, depth) => {
    if (depth === 0) return;
    const ex = bx + Math.sin(angle) * len, ey = by - Math.cos(angle) * len;
    s += `<path d="M${bx} ${by} L ${ex} ${ey}" stroke="${color}" stroke-width="${depth * size * 0.018 + 2}" stroke-linecap="round"/>`;
    branch(ex, ey, angle - 0.35, len * 0.72, depth - 1);
    branch(ex, ey, angle + 0.35, len * 0.72, depth - 1);
  };
  branch(x, y - size * 0.3, 0, size * 0.32, 5);
  return s + '</g>';
}

function anemone(x, y, size, color = '#45e8ea', glow = true) {
  let s = glow ? `<circle cx="${x}" cy="${y - size * 0.5}" r="${size * 1.1}" fill="url(#cyanGlow)"/>` : '';
  s += `<g filter="url(#shadow)">`;
  for (let i = 0; i < 11; i++) {
    const a = -1.2 + (i / 10) * 2.4;
    const ex = x + Math.sin(a) * size, ey = y - size * 0.3 - Math.cos(a) * size * 0.9;
    s += `<path d="M${x} ${y - size * 0.25} Q ${x + Math.sin(a) * size * 0.3} ${ey + size * 0.2}, ${ex} ${ey}" stroke="${color}" stroke-width="${size * 0.13}" fill="none" stroke-linecap="round"/>`;
    s += `<circle cx="${ex}" cy="${ey}" r="${size * 0.09}" fill="#e2ffff"/>`;
  }
  s += `<ellipse cx="${x}" cy="${y - size * 0.15}" rx="${size * 0.45}" ry="${size * 0.28}" fill="#1f8f9a"/>`;
  return s + '</g>';
}

function starCoral(x, y, size) {
  let s = `<circle cx="${x}" cy="${y - size * 0.9}" r="${size * 1.4}" fill="url(#glow)"/>`;
  s += `<g filter="url(#shadow)">`;
  s += `<path d="M${x} ${y} L ${x} ${y - size * 0.7}" stroke="#a88620" stroke-width="${size * 0.14}" stroke-linecap="round"/>`;
  for (let i = 0; i < 7; i++) {
    const a = -1.4 + (i / 6) * 2.8;
    const ex = x + Math.sin(a) * size * 0.8, ey = y - size * 0.75 - Math.cos(a) * size * 0.7;
    s += `<path d="M${x} ${y - size * 0.7} L ${ex} ${ey}" stroke="#ffd84a" stroke-width="${size * 0.1}" stroke-linecap="round"/>`;
    s += `<circle cx="${ex}" cy="${ey}" r="${size * 0.08}" fill="#fffbe0"/>`;
  }
  s += `<path d="${starPath(x, y - size * 0.95, size * 0.32, size * 0.14)}" fill="#fff6b8" stroke="#ffc21a" stroke-width="${size * 0.03}"/>`;
  return s + '</g>';
}

function starPath(cx, cy, outer, inner) {
  let d = '';
  for (let i = 0; i < 10; i++) {
    const a = (Math.PI / 5) * i - Math.PI / 2;
    const rr = i % 2 ? inner : outer;
    d += `${i ? 'L' : 'M'}${cx + Math.cos(a) * rr} ${cy + Math.sin(a) * rr} `;
  }
  return d + 'Z';
}

function clam(x, y, size) {
  return `<g filter="url(#shadow)">
    <path d="M${x - size} ${y} Q ${x} ${y + size * 0.45} ${x + size} ${y} Z" fill="#e9e6f2" stroke="#b6aecb" stroke-width="${size * 0.04}"/>
    <path d="M${x - size} ${y} Q ${x - size * 0.9} ${y - size * 1.1} ${x} ${y - size * 1.0} Q ${x + size * 0.9} ${y - size * 1.1} ${x + size} ${y} Z" fill="#f6f3fb" stroke="#b6aecb" stroke-width="${size * 0.04}"/>
    ${[-0.6, -0.3, 0, 0.3, 0.6].map(t => `<path d="M${x} ${y - size * 0.05} L ${x + t * size * 1.1} ${y - size * 0.95}" stroke="#d2cbe2" stroke-width="${size * 0.04}"/>`).join('')}
    <circle cx="${x}" cy="${y - size * 0.05}" r="${size * 0.32}" fill="url(#pearl)"/>
  </g>`;
}

function fish(x, y, size, body, fin, flip = false, glow = false) {
  const sx = flip ? -1 : 1;
  let s = `<g transform="translate(${x} ${y}) scale(${sx} 1)" filter="url(#shadow)">`;
  if (glow) s += `<circle r="${size * 1.6}" fill="url(#cyanGlow)"/>`;
  s += `<path d="M${-size * 0.9} 0 L ${-size * 1.6} ${-size * 0.6} L ${-size * 1.45} 0 L ${-size * 1.6} ${size * 0.6} Z" fill="${fin}"/>`;
  s += `<path d="M${-size * 0.2} ${-size * 0.5} Q ${size * 0.1} ${-size * 1.0} ${size * 0.4} ${-size * 0.45} Z" fill="${fin}"/>`;
  s += `<ellipse cx="0" cy="0" rx="${size}" ry="${size * 0.62}" fill="${body}"/>`;
  s += `<path d="M${-size * 0.1} ${-size * 0.6} Q ${-size * 0.35} 0 ${-size * 0.1} ${size * 0.6}" stroke="${fin}" stroke-width="${size * 0.16}" fill="none" opacity="0.8"/>`;
  s += `<circle cx="${size * 0.5}" cy="${-size * 0.12}" r="${size * 0.2}" fill="#fff"/><circle cx="${size * 0.55}" cy="${-size * 0.12}" r="${size * 0.11}" fill="#102033"/>`;
  s += `<circle cx="${size * 0.5}" cy="${-size * 0.17}" r="${size * 0.04}" fill="#fff"/>`;
  s += `<path d="M${size * 0.78} ${size * 0.15} q ${size * 0.08} ${size * 0.08} ${size * 0.16} 0" stroke="#102033" stroke-width="${size * 0.05}" fill="none" stroke-linecap="round"/>`;
  return s + '</g>';
}

function whale(x, y, size) {
  return `<g transform="translate(${x} ${y})" opacity="0.9">
    <path d="M${-size} 0 C ${-size * 0.8} ${-size * 0.45}, ${size * 0.3} ${-size * 0.55}, ${size * 0.8} ${-size * 0.12}
             C ${size} ${0}, ${size} ${size * 0.18}, ${size * 0.75} ${size * 0.22}
             C ${size * 0.2} ${size * 0.3}, ${-size * 0.6} ${size * 0.25}, ${-size} 0 Z" fill="#2f6fb3"/>
    <path d="M${-size * 0.6} ${size * 0.12} C ${-size * 0.1} ${size * 0.3}, ${size * 0.5} ${size * 0.28}, ${size * 0.8} ${size * 0.16}" stroke="#8fc3ea" stroke-width="${size * 0.06}" fill="none" opacity="0.6"/>
    <path d="M${-size * 0.95} 0 L ${-size * 1.35} ${-size * 0.3} Q ${-size * 1.2} 0 ${-size * 1.35} ${size * 0.25} Z" fill="#2f6fb3"/>
    <path d="M${size * 0.1} ${size * 0.2} Q ${size * 0.05} ${size * 0.5} ${-size * 0.25} ${size * 0.55} Q ${-size * 0.05} ${size * 0.35} ${-size * 0.05} ${size * 0.2} Z" fill="#24578f"/>
    <circle cx="${size * 0.6}" cy="${-size * 0.02}" r="${size * 0.035}" fill="#e8f6ff"/>
  </g>`;
}

function chest(x, y, size) {
  return `<g filter="url(#shadow)">
    <circle cx="${x}" cy="${y - size * 0.5}" r="${size * 1.3}" fill="url(#glow)"/>
    <rect x="${x - size}" y="${y - size * 0.7}" width="${size * 2}" height="${size * 0.9}" rx="${size * 0.08}" fill="#8a4f22" stroke="#4d2a0f" stroke-width="${size * 0.06}"/>
    <path d="M${x - size} ${y - size * 0.7} Q ${x} ${y - size * 1.55} ${x + size} ${y - size * 0.7} Z" fill="#a3602b" stroke="#4d2a0f" stroke-width="${size * 0.06}"/>
    <rect x="${x - size * 0.15}" y="${y - size * 0.85}" width="${size * 0.3}" height="${size * 0.4}" fill="url(#gold)" stroke="#7a4b00" stroke-width="${size * 0.04}"/>
    <rect x="${x - size}" y="${y - size * 0.35}" width="${size * 2}" height="${size * 0.12}" fill="url(#gold)"/>
    ${[0, 1, 2, 3, 4].map(i => `<circle cx="${x - size * 0.6 + i * size * 0.3}" cy="${y - size * 1.15 - (i % 2) * size * 0.15}" r="${size * 0.13}" fill="url(#gold)" stroke="#a86a00" stroke-width="${size * 0.03}"/>`).join('')}
  </g>`;
}

function title(x, y, size, text, fill = '#ffe066', stroke = '#0b2a4a', anchor = 'middle') {
  return `<text x="${x}" y="${y}" text-anchor="${anchor}" font-family="Fredoka" font-weight="700" font-size="${size}"
    fill="${fill}" stroke="${stroke}" stroke-width="${size * 0.16}" paint-order="stroke" stroke-linejoin="round"
    filter="url(#shadow)">${text}</text>`;
}

function badge(x, y, w, h, text, bg, fg = '#fff', size) {
  return `<g filter="url(#shadow)"><rect x="${x - w / 2}" y="${y - h / 2}" width="${w}" height="${h}" rx="${h / 2}" fill="${bg}" stroke="#0b2a4a" stroke-width="6"/>
    <text x="${x}" y="${y + size * 0.35}" text-anchor="middle" font-family="Fredoka" font-weight="700" font-size="${size}" fill="${fg}">${text}</text></g>`;
}

// ---------- compositions ----------
function icon() {
  seed = 11;
  const W = 512, H = 512;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${defs}
    <rect width="${W}" height="${H}" fill="url(#water)"/>
    ${rays(W, H, 6)}
    ${bubbles(W, H * 0.6, 14, 4, 12)}
    ${seabed(W, H, 400)}
    ${kelp(70, 440, 260, 1.1)}
    ${kelp(450, 440, 230, 1.0, '#3db455')}
    ${seaFan(380, 430, 180)}
    ${starCoral(256, 400, 120)}
    ${brainCoral(150, 452, 70)}
    ${anemone(360, 470, 60)}
    ${clam(250, 470, 55)}
    ${fish(120, 255, 34, '#ff9a3c', '#e0601a')}
    ${fish(400, 200, 26, '#4f8dff', '#2a5fd1', true)}
    ${title(256, 108, 92, 'GROW A')}
    ${title(256, 196, 108, 'REEF', '#7dffcf')}
  </svg>`;
}

function thumbMain() {
  seed = 21;
  const W = 1920, H = 1080;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${defs}
    <rect width="${W}" height="${H}" fill="url(#water)"/>
    ${rays(W, H, 12)}
    ${bubbles(W, H * 0.75, 40, 6, 22)}
    ${seabed(W, H, 820)}
    ${kelp(120, 900, 520, 2.0)}
    ${kelp(1800, 900, 480, 1.9, '#3db455')}
    ${seaFan(1500, 880, 360)}
    ${brainCoral(430, 930, 140)}
    ${starCoral(960, 860, 220)}
    ${anemone(1240, 960, 120)}
    ${clam(700, 980, 100)}
    ${seaFan(300, 900, 250, '#ff7ab8')}
    ${anemone(1700, 1000, 90, '#ff9de2', false)}
    ${fish(330, 520, 70, '#ff9a3c', '#e0601a')}
    ${fish(1600, 430, 60, '#4f8dff', '#2a5fd1', true)}
    ${fish(1450, 620, 44, '#ffd84a', '#e0a100', true)}
    ${fish(660, 600, 42, '#e6e9ff', '#9aa6e8', false, true)}
    ${title(960, 230, 210, 'GROW A REEF')}
    ${badge(960, 360, 760, 92, 'Plant • Harvest • Catch • Collect!', '#ff5fa2', '#fff', 50)}
  </svg>`;
}

function thumbMutations() {
  seed = 31;
  const W = 1920, H = 1080;
  const pedestal = (x, label, color, mult, inner) => `
    <ellipse cx="${x}" cy="860" rx="210" ry="50" fill="#0a3156" opacity="0.6"/>
    ${inner}
    ${badge(x, 960, 360, 96, `${label} x${mult}`, color, '#0b2a4a', 54)}`;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${defs}
    <rect width="${W}" height="${H}" fill="url(#water)"/>
    ${rays(W, H, 10, 0.8)}
    ${bubbles(W, H, 35, 6, 20)}
    ${seabed(W, H, 880)}
    ${pedestal(420, 'Glowing', '#7dffcf', 2, `<circle cx="420" cy="660" r="260" fill="url(#cyanGlow)"/>${brainCoral(420, 860, 170, '#8affd6', '#2fbf8f')}`)}
    ${pedestal(960, 'Golden', '#ffc21a', 5, `<circle cx="960" cy="660" r="280" fill="url(#glow)"/>${brainCoral(960, 860, 180, 'url(#gold)', '#a86a00')}`)}
    ${pedestal(1500, 'Prismatic', '#ff9de2', 15, `<circle cx="1500" cy="660" r="300" fill="url(#glow)" opacity="0.7"/>${brainCoral(1500, 860, 190, 'url(#prism)', '#7a3cbf')}
       <path d="${starPath(1330, 520, 40, 16)}" fill="#fff"/><path d="${starPath(1680, 600, 32, 12)}" fill="#fff"/><path d="${starPath(1620, 440, 26, 10)}" fill="#fff"/>`)}
    ${title(960, 230, 190, 'RARE MUTATIONS!', '#ffffff')}
    ${title(960, 340, 80, 'Up to 15x the shells', '#ffe066')}
  </svg>`;
}

function thumbEvents() {
  seed = 41;
  const W = 1920, H = 1080;
  let plankton = '';
  for (let i = 0; i < 90; i++) plankton += `<circle cx="${r(0, W)}" cy="${r(0, H)}" r="${r(2, 6)}" fill="#8ffcff" opacity="${r(0.4, 0.9)}"/>`;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${defs}
    <rect width="${W}" height="${H}" fill="url(#nightWater)"/>
    <g filter="url(#soft)">${plankton}</g>${plankton}
    <ellipse cx="1180" cy="600" rx="560" ry="230" fill="#3f8fd8" opacity="0.25" filter="url(#soft)"/>${whale(1180, 600, 400)}
    ${bubbles(W, H * 0.7, 20, 6, 18)}
    ${seabed(W, H, 850)}
    <rect x="0" y="830" width="${W}" height="${H - 830}" fill="#030b24" opacity="0.45"/>
    ${anemone(250, 980, 150)}
    ${anemone(1700, 990, 130)}
    ${starCoral(560, 940, 150)}
    ${chest(1300, 1000, 130)}
    ${chest(880, 1010, 90)}
    ${fish(1790, 560, 50, '#e6e9ff', '#9aa6e8', true, true)}
    ${fish(420, 640, 45, '#e6e9ff', '#9aa6e8', false, true)}
    ${title(960, 210, 190, 'SEA EVENTS!', '#9ffcff', '#061633')}
    ${badge(960, 340, 1120, 90, 'Whale Pass • Glowing Night • Treasure Storm', '#ffc21a', '#0b2a4a', 48)}
  </svg>`;
}

(async () => {
  const fontCss = 'https://fonts.googleapis.com/css2?family=Fredoka:wght@700&display=block';
  const jobs = [
    ['icon-512.png', icon(), 512, 512],
    ['thumbnail-1-main.png', thumbMain(), 1920, 1080],
    ['thumbnail-2-mutations.png', thumbMutations(), 1920, 1080],
    ['thumbnail-3-events.png', thumbEvents(), 1920, 1080],
  ];
  const browser = await chromium.launch();
  for (const [name, svg, w, h] of jobs) {
    const page = await browser.newPage({ viewport: { width: w, height: h }, deviceScaleFactor: 1 });
    await page.setContent(`<!doctype html><html><head><link rel="stylesheet" href="${fontCss}">
      <style>html,body{margin:0;background:#000}svg{display:block}</style></head><body>${svg}</body></html>`);
    await page.evaluate(() => document.fonts.ready);
    const ok = await page.evaluate(() => document.fonts.check('700 40px Fredoka'));
    await page.screenshot({ path: path.join(outDir, name), clip: { x: 0, y: 0, width: w, height: h } });
    fs.writeFileSync(path.join(outDir, name.replace('.png', '.svg')), svg);
    console.log(name, 'font loaded:', ok);
    await page.close();
  }
  await browser.close();
})();
