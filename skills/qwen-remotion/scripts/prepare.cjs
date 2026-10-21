// Validate content.json and write data.json for video.tsx.
// Any problem prints exactly one "FIX: ..." line and exits 4. Geometry is checked later in video.tsx.
const fs = require('fs');
const [src, dst] = process.argv.slice(2);
const fail = (m) => { console.log('FIX: ' + m); process.exit(4); };

let c;
try { c = JSON.parse(fs.readFileSync(src, 'utf8')); } catch (e) { fail(`content.json is not valid JSON: ${e.message.split('\n')[0]}`); }
const text = (v, max, what, empty = false) => {
  if (typeof v !== 'string' || (!empty && !v.trim())) fail(`${what} must be ${empty ? 'a' : 'a non-empty'} string`);
  v = v.trim().replace(/\s+/g, ' ');
  if (v.length > max) fail(`${what} "${v}" is ${v.length} chars; cut it to ${max} or fewer`);
  return v;
};
const list = (v, min, max, what) => {
  if (!Array.isArray(v) || v.length < min || v.length > max) fail(`${what} must be a list of ${min}-${max} items (now ${Array.isArray(v) ? v.length : 'missing'})`);
  return v;
};
const allowed = ['title', 'subtitle', 'lanes', 'links', 'scenes'];
for (const k of Object.keys(c)) if (!allowed.includes(k)) fail(`remove field "${k}"; only ${allowed.join(', ')} are used`);

const title = text(c.title, 48, 'title');
const subtitle = text(c.subtitle, 90, 'subtitle');
const owner = new Map(); // lower-case label -> lane name
const lanes = list(c.lanes, 1, 4, 'lanes').map((lane, li) => {
  const name = text(lane && lane.name, 20, `lanes[${li}].name`);
  const parts = list(lane.parts, 1, 6, `lane "${name}" parts`).map((p, pi) => {
    if (!Array.isArray(p) || p.length !== 2) fail(`lane "${name}" part ${pi + 1} must be ["Label", "detail"]`);
    const label = text(p[0], 18, `part label`);
    const detail = text(p[1], 28, `detail of "${label}"`);
    if (owner.has(label.toLowerCase())) fail(`part label "${label}" is used twice; make each label unique`);
    owner.set(label.toLowerCase(), name);
    return { label, detail };
  });
  return { name, parts };
});
const labels = lanes.flatMap((l) => l.parts.map((p) => p.label));
if (labels.length < 3 || labels.length > 18) fail(`use 3-18 parts in total (now ${labels.length})`);
const exact = (v, where) => {
  const hit = labels.find((l) => l === v) || labels.find((l) => typeof v === 'string' && l.toLowerCase() === v.trim().toLowerCase());
  if (!hit) fail(`${where} names "${v}", which is not a part label; use one of: ${labels.join(', ')}`);
  return hit;
};

const seen = new Set();
const links = list(c.links, 2, 24, 'links').map((k, i) => {
  if (!Array.isArray(k) || k.length !== 3) fail(`links[${i}] must be ["From", "To", "verb"]`);
  const from = exact(k[0], `links[${i}]`), to = exact(k[1], `links[${i}]`);
  const verb = text(k[2], 14, `verb of link ${from} -> ${to}`, true);
  if (from === to) fail(`link ${from} -> ${to} points to itself; remove it`);
  if (seen.has(from + '\n' + to)) fail(`link ${from} -> ${to} appears twice; keep one`);
  seen.add(from + '\n' + to);
  return { from, to, verb };
});
for (const l of labels) if (!links.some((k) => k.from === l || k.to === l)) fail(`part "${l}" has no link; link it to what it acts on, or remove it`);

const says = new Set([title.toLowerCase(), subtitle.toLowerCase()]);
const scenes = list(c.scenes, 3, 8, 'scenes').map((s, i) => {
  const say = text(s && s.say, 110, `scenes[${i}].say`);
  if (says.has(say.toLowerCase())) fail(`scenes[${i}].say repeats the title, subtitle or another scene; say what happens in this scene`);
  says.add(say.toLowerCase());
  if (!s.focus || typeof s.focus !== 'object' || Array.isArray(s.focus) || !Object.keys(s.focus).length) fail(`scenes[${i}].focus must be an object like {"Label": "state"} with at least one part`);
  const focus = {};
  for (const [k, v] of Object.entries(s.focus)) focus[exact(k, `scenes[${i}].focus`)] = text(v, 14, `state of "${k}" in scenes[${i}]`, true);
  return { say, focus };
});
for (const l of labels) if (!scenes.some((s) => l in s.focus)) fail(`part "${l}" is never in a scene focus, so it never appears; add it to a scene's focus`);

fs.writeFileSync(dst, JSON.stringify({ title, subtitle, lanes, links, scenes }, null, 1));
