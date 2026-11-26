'use strict';

const $ = (id) => document.getElementById(id);
const video = $('video');
const subsEl = $('subs');
const badge = $('badge');
const trackSelect = $('track');
const autoGenerate = $('auto-generate');
const hoverPause = $('hover-pause');

const AI_TRACK = '__ai__';
const OFF_TRACK = '__off__';

let files = [];
let current = null;
let cues = [];
let shownKey = '';
let autoPaused = false;
let pollTimer = null;
// Bumped on every file/track switch so stale polls and fetches drop their results.
let loadToken = 0;

const store = {
  get(key, fallback) {
    try {
      const v = localStorage.getItem(key);
      return v === null ? fallback : JSON.parse(v);
    } catch {
      return fallback;
    }
  },
  set(key, value) {
    try {
      localStorage.setItem(key, JSON.stringify(value));
    } catch {}
  },
};

const encodePath = (rel) => rel.split('/').map(encodeURIComponent).join('/');

function parseTime(h, m, s, ms) {
  return parseInt(h || '0', 10) * 3600 + parseInt(m, 10) * 60 + parseInt(s, 10) + parseInt(ms, 10) / 1000;
}

function parseSrtVtt(text) {
  const timing = /(?:(\d+):)?(\d{1,2}):(\d{2})[.,](\d{3})\s*-->\s*(?:(\d+):)?(\d{1,2}):(\d{2})[.,](\d{3})/;
  const out = [];
  for (const block of text.replace(/\r/g, '').split(/\n{2,}/)) {
    const lines = block.split('\n');
    const i = lines.findIndex((l) => timing.test(l));
    if (i < 0) continue;
    const m = lines[i].match(timing);
    const body = lines.slice(i + 1).join('\n').replace(/<[^>]+>/g, '').replace(/\{\\[^}]*\}/g, '').trim();
    if (body) out.push({ start: parseTime(m[1], m[2], m[3], m[4]), end: parseTime(m[5], m[6], m[7], m[8]), text: body });
  }
  return out.sort((a, b) => a.start - b.start);
}

function setBadge(text, isError = false) {
  badge.hidden = !text;
  badge.textContent = text || '';
  badge.classList.toggle('error', isError);
}

function renderCues() {
  const t = video.currentTime;
  const active = [];
  for (let i = 0; i < cues.length && cues[i].start <= t; i++) {
    if (cues[i].end > t) active.push(i);
  }
  const key = active.join(',');
  // Only touch the DOM when the line changes, or Yomitan loses its hover target every frame.
  if (key === shownKey) return;
  shownKey = key;
  subsEl.textContent = active.map((i) => cues[i].text).join('\n');
}

function setCues(next) {
  cues = next;
  shownKey = null;
  renderCues();
}

function tick() {
  renderCues();
  requestAnimationFrame(tick);
}

function stopPolling() {
  clearTimeout(pollTimer);
  pollTimer = null;
}

async function api(path, options) {
  const res = await fetch(path, options);
  if (!res.ok) throw new Error(`${res.status} ${await res.text()}`);
  return res.json();
}

async function loadAiTrack(token, start) {
  const q = `?path=${encodeURIComponent(current.path)}`;
  let job;
  try {
    job = start
      ? await api(`/api/transcribe${q}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}' })
      : await api(`/api/subs${q}`);
  } catch (e) {
    if (token === loadToken) setBadge(`Subtitle server error: ${e.message}`, true);
    return;
  }
  if (token !== loadToken) return;

  if (job.status === 'none') {
    setCues([]);
    if (autoGenerate.checked) return loadAiTrack(token, true);
    setBadge('No AI subtitles yet — press g to generate');
    return;
  }
  if (job.segments) setCues(job.segments);
  if (job.status === 'done') {
    setBadge('');
    current.cached = true;
    renderFiles();
    return;
  }
  if (job.status === 'error') {
    setBadge(`Transcription failed: ${job.error} (press g to retry)`, true);
    return;
  }
  const label = {
    queued: 'Queued for transcription…',
    'loading-model': 'Loading Whisper model…',
    running: `Transcribing… ${Math.round(job.progress * 100)}%`,
  }[job.status] || job.status;
  setBadge(label);
  pollTimer = setTimeout(() => loadAiTrack(token, false), 2000);
}

async function selectTrack(value) {
  stopPolling();
  const token = ++loadToken;
  setCues([]);
  setBadge('');
  if (!current) return;
  store.set('track', value === AI_TRACK || value === OFF_TRACK ? value : 'sidecar');
  if (value === OFF_TRACK) return;
  if (value === AI_TRACK) return loadAiTrack(token, false);
  try {
    const res = await fetch(`/media/${encodePath(value)}`);
    const text = await res.text();
    if (token === loadToken) setCues(parseSrtVtt(text));
  } catch (e) {
    if (token === loadToken) setBadge(`Couldn't load ${value}: ${e.message}`, true);
  }
}

function buildTrackOptions() {
  trackSelect.replaceChildren();
  const add = (value, label) => trackSelect.append(new Option(label, value));
  add(AI_TRACK, 'AI (Whisper)');
  for (const sub of current.subs) add(sub, sub.split('/').pop());
  add(OFF_TRACK, 'Off');
  const pref = store.get('track', AI_TRACK);
  trackSelect.value = pref === 'sidecar' && current.subs.length ? current.subs[0] : pref === OFF_TRACK ? OFF_TRACK : AI_TRACK;
}

function savePosition() {
  if (!current || !video.duration) return;
  const positions = store.get('positions', {});
  // Finished episodes restart from the top instead of resuming at the credits.
  if (video.currentTime > video.duration - 30) delete positions[current.path];
  else positions[current.path] = Math.floor(video.currentTime);
  store.set('positions', positions);
}

function openFile(file) {
  savePosition();
  current = file;
  store.set('last', file.path);
  $('title').textContent = file.path;
  document.title = `${file.path.split('/').pop()} · Immersion Player`;
  renderFiles();
  buildTrackOptions();
  video.src = `/media/${encodePath(file.path)}`;
  const resumeAt = store.get('positions', {})[file.path];
  video.addEventListener('loadedmetadata', () => {
    if (resumeAt) video.currentTime = resumeAt;
  }, { once: true });
  selectTrack(trackSelect.value);
}

function renderFiles() {
  const needle = $('filter').value.trim().toLowerCase();
  const list = $('files');
  list.replaceChildren();
  for (const file of files) {
    if (needle && !file.path.toLowerCase().includes(needle)) continue;
    const li = document.createElement('li');
    const slash = file.path.lastIndexOf('/');
    if (slash >= 0) {
      const dir = document.createElement('div');
      dir.className = 'dir';
      dir.textContent = file.path.slice(0, slash);
      li.append(dir);
    }
    li.append(file.path.slice(slash + 1));
    if (file.cached) {
      const tag = document.createElement('span');
      tag.className = 'tag';
      tag.textContent = 'AI subs';
      li.append(tag);
    }
    li.classList.toggle('active', file === current);
    li.addEventListener('click', () => openFile(file));
    list.append(li);
  }
}

function seekToCue(direction) {
  if (!cues.length) return;
  const t = video.currentTime;
  let target;
  if (direction < 0) {
    // Small grace window so pressing "previous" mid-line goes to the line before, not the start of this one.
    const before = cues.filter((c) => c.start < t - 1);
    target = before[before.length - 1];
  } else if (direction > 0) {
    target = cues.find((c) => c.start > t + 0.05);
  } else {
    target = [...cues].reverse().find((c) => c.start <= t);
  }
  if (target) video.currentTime = target.start;
}

function toggleFullscreen() {
  if (document.fullscreenElement) document.exitFullscreen();
  else $('player').requestFullscreen();
}

document.addEventListener('keydown', (e) => {
  if (e.target.matches('input[type=search], select') || e.ctrlKey || e.metaKey || e.altKey) return;
  const actions = {
    ' ': () => (video.paused ? video.play() : video.pause()),
    ArrowLeft: () => (video.currentTime -= 5),
    ArrowRight: () => (video.currentTime += 5),
    a: () => seekToCue(-1),
    d: () => seekToCue(1),
    r: () => seekToCue(0),
    s: () => subsEl.classList.toggle('hidden'),
    f: toggleFullscreen,
    g: () => {
      if (!current) return;
      trackSelect.value = AI_TRACK;
      stopPolling();
      loadAiTrack(++loadToken, true);
    },
  };
  const action = actions[e.key];
  if (!action) return;
  e.preventDefault();
  action();
});

subsEl.addEventListener('mouseenter', () => {
  if (hoverPause.checked && !video.paused) {
    video.pause();
    autoPaused = true;
  }
});
// Resume only once the pointer is back on the video, so moving into the Yomitan popup keeps it paused.
video.addEventListener('mouseenter', () => {
  if (autoPaused) video.play();
});
video.addEventListener('play', () => {
  autoPaused = false;
});
video.addEventListener('pause', savePosition);
video.addEventListener('dblclick', toggleFullscreen);
video.addEventListener('error', () => {
  if (video.error) setBadge("This browser can't play this file (codec unsupported) — try remuxing to mp4", true);
});
window.addEventListener('beforeunload', savePosition);
setInterval(savePosition, 10000);

trackSelect.addEventListener('change', () => selectTrack(trackSelect.value));
$('filter').addEventListener('input', renderFiles);
$('fullscreen').addEventListener('click', toggleFullscreen);
for (const box of [autoGenerate, hoverPause]) {
  box.checked = store.get(box.id, box.checked);
  box.addEventListener('change', () => store.set(box.id, box.checked));
}

(async () => {
  try {
    files = await api('/api/files');
  } catch (e) {
    setBadge(`Couldn't list videos: ${e.message}`, true);
    return;
  }
  renderFiles();
  const last = files.find((f) => f.path === store.get('last', null));
  if (last) openFile(last);
  requestAnimationFrame(tick);
})();
