// Script-owned layout + animation for qwen-remotion. Qwen never edits this file.
// Lanes are rows; parts are evenly spaced in each row; links are curves (same-lane forward links arc
// above, backward links arc below, so loops read as cycles). On mount it checks the real rendered
// geometry and throws "FIX: ..." (text overflow, overlaps, links through parts) so make.sh can report it.
import React, { useLayoutEffect, useRef } from 'react';
import { Composition, Easing, interpolate, registerRoot, spring, useCurrentFrame } from 'remotion';
import raw from './data.json';

type Pt = [number, number];
type Data = {
  title: string; subtitle: string;
  lanes: { name: string; parts: { label: string; detail: string }[] }[];
  links: { from: string; to: string; verb: string }[];
  scenes: { say: string; focus: Record<string, string> }[];
};
const D = raw as Data;
const FPS = 30, SCENE = 7 * FPS, FADE = 12;
const AREA = { left: 300, right: 1860, top: 186, bottom: 884 };
const NODE_H = 120, CAPTION = { left: 160, top: 912, width: 1600, height: 128 };
const COLORS = ['#0D9488', '#2563EB', '#C2410C', '#9333EA'];
const INK = '#0F172A', SLATE = '#475569', MUTED = '#94A3B8', PAPER = '#F8FAFC';
const FONT = 'Inter, "DejaVu Sans", Arial, sans-serif';

// ---- layout (static) ----
const laneH = (AREA.bottom - AREA.top) / D.lanes.length;
const maxParts = Math.max(...D.lanes.map((l) => l.parts.length));
const nodeW = Math.min(340, (AREA.right - AREA.left) / maxParts - 40);
const lift = Math.max(14, Math.min((laneH - NODE_H) / 2, 56));
type Node = { label: string; detail: string; lane: number; index: number; x: number; y: number; cx: number; color: string };
const nodes: Record<string, Node> = {};
D.lanes.forEach((lane, li) => {
  const slot = (AREA.right - AREA.left) / lane.parts.length;
  lane.parts.forEach((p, i) => {
    const cx = AREA.left + slot * (i + 0.5);
    nodes[p.label] = { ...p, lane: li, index: i, cx, x: cx - nodeW / 2, y: AREA.top + li * laneH + (laneH - NODE_H) / 2, color: COLORS[li] };
  });
});
const curves = D.links.map((k) => {
  const a = nodes[k.from], b = nodes[k.to];
  let p: Pt[];
  if (a.lane === b.lane) {
    const fwd = a.index < b.index, off = nodeW * 0.22, y = fwd ? a.y : a.y + NODE_H, s = fwd ? 1 : -1;
    const x1 = a.cx + s * off, x2 = b.cx - s * off, cy = y - s * 2 * lift;
    p = [[x1, y], [x1 + (x2 - x1) * 0.25, cy], [x1 + (x2 - x1) * 0.75, cy], [x2, y]];
  } else {
    const down = a.lane < b.lane, back = D.links.some((r) => r.from === k.to && r.to === k.from), shift = back ? (down ? 1 : -1) * nodeW * 0.16 : 0;
    const y1 = down ? a.y + NODE_H : a.y, y2 = down ? b.y : b.y + NODE_H, h = (y2 - y1) / 2;
    p = [[a.cx + shift, y1], [a.cx + shift, y1 + h], [b.cx + shift, y2 - h], [b.cx + shift, y2]];
  }
  const at = (t: number): Pt => {
    const u = 1 - t, w = [u * u * u, 3 * u * u * t, 3 * u * t * t, t * t * t];
    return [0, 1].map((d) => w.reduce((sum, wi, i) => sum + wi * p[i][d], 0)) as Pt;
  };
  return { ...k, at, d: `M${p[0]} C${p[1]} ${p[2]} ${p[3]}` };
});
const firstScene: Record<string, number> = {};
D.scenes.forEach((s, i) => Object.keys(s.focus).forEach((l) => { if (!(l in firstScene)) firstScene[l] = i; }));

// ---- geometry check on the real DOM ----
function check(root: HTMLElement): string | null {
  for (const c of curves) for (let t = 0; t <= 1; t += 0.01) {
    const [x, y] = c.at(t);
    const hit = Object.values(nodes).find((n) => n.label !== c.from && n.label !== c.to && x > n.x + 2 && x < n.x + nodeW - 2 && y > n.y + 2 && y < n.y + NODE_H - 2);
    if (hit) return `link ${c.from} -> ${c.to} runs through part "${hit.label}"; reorder the parts in lane "${D.lanes[hit.lane].name}" or remove that link`;
  }
  for (const e of Array.from(root.querySelectorAll<HTMLElement>('[data-fit]'))) {
    const w = e.scrollWidth / e.clientWidth, h = e.scrollHeight / e.clientHeight, r = Math.max(w, h), t = e.dataset.fit!;
    if (r > 1.01) return `"${t}" does not fit its box; cut it to about ${Math.max(1, Math.floor(t.length / r) - 1)} chars`;
  }
  const scale = root.getBoundingClientRect().width / 1920;
  const boxes = Array.from(root.querySelectorAll<HTMLElement>('[data-box]')).map((e) => ({ name: e.dataset.box!, r: e.getBoundingClientRect() }));
  for (let i = 0; i < boxes.length; i++) for (let j = i + 1; j < boxes.length; j++) {
    const a = boxes[i].r, b = boxes[j].r, m = 3 * scale;
    if (a.left < b.right - m && b.left < a.right - m && a.top < b.bottom - m && b.top < a.bottom - m)
      return `${boxes[i].name} overlaps ${boxes[j].name}; set one of those link verbs to "" or shorten it, or reorder parts so linked parts sit closer`;
  }
  return null;
}

// ---- pieces ----
const chipStyle = (color: string): React.CSSProperties => ({ display: 'inline-block', maxWidth: nodeW - 32, boxSizing: 'border-box', overflow: 'hidden', whiteSpace: 'nowrap', background: color, color: 'white', fontSize: 21, fontWeight: 800, lineHeight: '30px', padding: '0 12px', borderRadius: 8 });
const captionStyle: React.CSSProperties = { width: CAPTION.width, height: CAPTION.height, boxSizing: 'border-box', overflow: 'hidden', padding: '14px 32px', borderRadius: 20, background: 'rgba(15,23,42,.92)', color: 'white', fontSize: 38, lineHeight: '50px', fontWeight: 600, textAlign: 'center', display: 'flex', alignItems: 'center', justifyContent: 'center' };
const line = (size: number, weight: number, color: string): React.CSSProperties => ({ fontSize: size, lineHeight: `${Math.round(size * 1.18)}px`, fontWeight: weight, color, whiteSpace: 'nowrap', overflow: 'hidden' });

const Explainer: React.FC = () => {
  const frame = useCurrentFrame();
  const root = useRef<HTMLDivElement>(null);
  useLayoutEffect(() => { const problem = check(root.current!); if (problem) throw new Error('FIX: ' + problem); }, []);
  const s = Math.min(D.scenes.length - 1, Math.floor(frame / SCENE)), local = frame - s * SCENE;
  const ease = interpolate(local, [0, FADE], [0, 1], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: Easing.inOut(Easing.cubic) });
  const focus = (l: string) => {
    const prev = s > 0 && l in D.scenes[s - 1].focus ? 1 : 0;
    return prev + ((l in D.scenes[s].focus ? 1 : 0) - prev) * ease;
  };
  const shown = (l: string) => (firstScene[l] < s ? 1 : firstScene[l] === s ? ease : 0);
  const glow = 0.5 + 0.5 * Math.sin(frame / 8);
  const pop = spring({ frame: local - 6, fps: FPS, config: { damping: 12 } });
  return (
    <div ref={root} style={{ position: 'absolute', inset: 0, background: PAPER, color: INK, fontFamily: FONT, overflow: 'hidden' }}>
      <div data-box="the title" style={{ position: 'absolute', left: 60, top: 36, width: 1500 }}>
        <div data-fit={D.title} style={{ ...line(52, 800, INK), letterSpacing: -1 }}>{D.title}</div>
        <div data-fit={D.subtitle} style={{ ...line(29, 500, SLATE), marginTop: 6 }}>{D.subtitle}</div>
      </div>
      <div style={{ position: 'absolute', right: 60, top: 60, display: 'flex', gap: 12 }}>
        {D.scenes.map((_, i) => <div key={i} style={{ width: 18, height: 18, borderRadius: 9, background: i <= s ? INK : '#CBD5E1' }} />)}
      </div>
      {D.lanes.map((lane, li) => (
        <div key={li}>
          <div style={{ position: 'absolute', left: 44, right: 44, top: AREA.top + li * laneH + 5, height: laneH - 10, borderRadius: 22, background: COLORS[li] + '0D', border: `1px solid ${COLORS[li]}26` }} />
          <div data-box={`lane name "${lane.name}"`} data-fit={lane.name} style={{ position: 'absolute', left: 64, width: 210, top: AREA.top + li * laneH + laneH / 2 - 32, height: 64, overflow: 'hidden', display: 'flex', alignItems: 'center', fontSize: 24, lineHeight: '30px', fontWeight: 800, letterSpacing: 0.5, textTransform: 'uppercase', color: COLORS[li] }}>{lane.name}</div>
        </div>
      ))}
      <svg width={1920} height={1080} style={{ position: 'absolute', left: 0, top: 0 }}>
        <defs>
          {[['g', MUTED], ['k', INK]].map(([id, c]) => <marker key={id} id={id} viewBox="0 0 10 10" refX={9} refY={5} markerUnits="userSpaceOnUse" markerWidth={20} markerHeight={20} orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill={c} /></marker>)}
        </defs>
        {curves.map((c, i) => {
          const vis = Math.min(shown(c.from), shown(c.to)), act = Math.min(focus(c.from), focus(c.to));
          const dot = c.at(((local % 45) / 45));
          return <g key={i} opacity={vis}>
            <path d={c.d} fill="none" stroke={MUTED} strokeWidth={3} markerEnd="url(#g)" />
            <path d={c.d} fill="none" stroke={INK} strokeWidth={5} strokeDasharray="16 10" strokeDashoffset={-frame * 1.6} markerEnd="url(#k)" opacity={act} />
            <circle cx={dot[0]} cy={dot[1]} r={8} fill={nodes[c.from].color} opacity={act} />
          </g>;
        })}
      </svg>
      {curves.filter((c) => c.verb).map((c, i) => {
        const [x, y] = c.at(0.5), act = Math.min(focus(c.from), focus(c.to));
        return <div key={i} data-box={`link verb "${c.verb}" (${c.from} -> ${c.to})`} style={{ position: 'absolute', left: x, top: y, transform: 'translate(-50%, -50%)', opacity: Math.min(shown(c.from), shown(c.to)), whiteSpace: 'nowrap', background: 'white', border: `2px solid ${act > 0.5 ? INK : '#CBD5E1'}`, borderRadius: 999, padding: '1px 12px', fontSize: 21, fontWeight: 700, color: act > 0.5 ? INK : SLATE }}>{c.verb}</div>;
      })}
      {Object.values(nodes).map((n) => {
        const f = focus(n.label), state = D.scenes[s].focus[n.label];
        return <div key={n.label} data-box={`part "${n.label}"`} style={{ position: 'absolute', left: n.x, top: n.y, width: nodeW, height: NODE_H, boxSizing: 'border-box', padding: '8px 12px', background: 'white', borderRadius: 16, border: `4px solid ${f > 0.5 ? n.color : '#CBD5E1'}`, boxShadow: f > 0.5 ? `0 0 ${10 + 14 * glow}px ${n.color}66` : '0 4px 14px rgba(15,23,42,.06)', opacity: shown(n.label) * (0.4 + 0.6 * f) }}>
          <div data-fit={n.label} style={line(29, 800, INK)}>{n.label}</div>
          <div data-fit={n.detail} style={line(23, 500, SLATE)}>{n.detail}</div>
          {state ? <div style={{ ...chipStyle(n.color), marginTop: 4, transform: `scale(${pop})`, transformOrigin: 'left center' }}>{state}</div> : null}
        </div>;
      })}
      <div key={s} style={{ position: 'absolute', left: CAPTION.left, top: CAPTION.top, opacity: ease }}>
        <div data-box="the caption" style={captionStyle}>{D.scenes[s].say}</div>
      </div>
      {/* Hidden copies of every caption and state, so one mount checks all scenes. */}
      <div style={{ position: 'absolute', left: 0, top: 0, visibility: 'hidden' }}>
        {D.scenes.map((sc, i) => <div key={i}>
          <div data-fit={sc.say} style={{ ...captionStyle, display: 'block' }}>{sc.say}</div>
          {Object.entries(sc.focus).filter(([, v]) => v).map(([k, v]) => <div key={k} style={{ width: nodeW - 32 }}><div data-fit={v} style={chipStyle(nodes[k].color)}>{v}</div></div>)}
        </div>)}
      </div>
    </div>
  );
};

const Root: React.FC = () => <Composition id="Explainer" component={Explainer} durationInFrames={D.scenes.length * SCENE} fps={FPS} width={1920} height={1080} />;
registerRoot(Root);
