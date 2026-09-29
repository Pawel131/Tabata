(() => {
  "use strict";
  const $ = (id) => document.getElementById(id);
  const COLORS = { prepare: "#E09A12", work: "#E4432A", rest: "#2A7AD4", setRest: "#6A57CF", done: "#23A064", paused: "#3A3D44" };
  const TITLES = { prepare: "Get Ready", work: "Work", rest: "Rest", setRest: "Set Rest" };
  const DEFAULT = { prepare: 10, work: 20, rest: 10, rounds: 8, sets: 1, setRest: 60 };
  const PRESETS = [
    { name: "Classic", c: { prepare: 10, work: 20, rest: 10, rounds: 8, sets: 1, setRest: 60 } },
    { name: "Beginner", c: { prepare: 10, work: 20, rest: 20, rounds: 6, sets: 1, setRest: 60 } },
    { name: "Double", c: { prepare: 10, work: 20, rest: 10, rounds: 8, sets: 2, setRest: 60 } },
    { name: "Endurance", c: { prepare: 10, work: 40, rest: 20, rounds: 10, sets: 1, setRest: 60 } },
    { name: "HIIT 45/15", c: { prepare: 10, work: 45, rest: 15, rounds: 8, sets: 3, setRest: 90 } },
  ];

  const load = (k, d) => { try { const v = localStorage.getItem(k); return v ? { ...d, ...JSON.parse(v) } : { ...d }; } catch { return { ...d }; } };
  const save = (k, v) => { try { localStorage.setItem(k, JSON.stringify(v)); } catch {} };

  let config = load("tabata.config", DEFAULT);
  let cues = load("tabata.cues", { beeps: true, voice: true });

  const clock = (s) => {
    s = Math.max(0, Math.round(s));
    const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), sec = s % 60;
    return h ? `${h}:${String(m).padStart(2, "0")}:${String(sec).padStart(2, "0")}` : `${m}:${String(sec).padStart(2, "0")}`;
  };
  const short = (s) => (s < 60 ? `${s}s` : clock(s));

  function buildPhases(c) {
    const out = [];
    if (c.prepare > 0) out.push({ kind: "prepare", dur: c.prepare, round: 1, set: 1 });
    for (let set = 1; set <= c.sets; set++) {
      for (let round = 1; round <= c.rounds; round++) {
        out.push({ kind: "work", dur: c.work, round, set });
        if (round < c.rounds && c.rest > 0) out.push({ kind: "rest", dur: c.rest, round, set });
      }
      if (set < c.sets && c.setRest > 0) out.push({ kind: "setRest", dur: c.setRest, round: c.rounds, set });
    }
    return out;
  }
  const totalOf = (c) => buildPhases(c).reduce((a, p) => a + p.dur, 0);

  // ---------- Setup view ----------
  const FIELDS = {
    intervals: [
      { key: "work", label: "Work", color: COLORS.work, min: 5, max: 600, step: 5, fmt: short },
      { key: "rest", label: "Rest", color: COLORS.rest, min: 0, max: 600, step: 5, fmt: short },
      { key: "prepare", label: "Get ready", color: COLORS.prepare, min: 0, max: 60, step: 5, fmt: short },
    ],
    rounds: [
      { key: "rounds", label: "Rounds", hint: "per set", min: 1, max: 50, step: 1, fmt: String },
      { key: "sets", label: "Sets", min: 1, max: 10, step: 1, fmt: String },
      { key: "setRest", label: "Rest between sets", color: COLORS.setRest, min: 0, max: 600, step: 10, fmt: short, showIf: (c) => c.sets > 1 },
    ],
  };

  function stepperRow(f) {
    const row = document.createElement("div");
    row.className = "row";
    row.innerHTML = `
      ${f.color ? `<span class="swatch" style="background:${f.color}"></span>` : ""}
      <div class="label"><span>${f.label}</span>${f.hint ? `<small>${f.hint}</small>` : ""}</div>
      <div class="stepper">
        <button type="button" id="dec-${f.key}" aria-label="Decrease ${f.label}">−</button>
        <output id="val-${f.key}" aria-live="polite"></output>
        <button type="button" id="inc-${f.key}" aria-label="Increase ${f.label}">+</button>
      </div>`;
    const bump = (dir) => {
      const v = Math.min(f.max, Math.max(f.min, config[f.key] + dir * f.step));
      if (v === config[f.key]) return;
      config[f.key] = v; save("tabata.config", config); renderSetup();
    };
    holdRepeat(row.querySelector(`#dec-${f.key}`), () => bump(-1));
    holdRepeat(row.querySelector(`#inc-${f.key}`), () => bump(1));
    return row;
  }

  // Tap to step once; press and hold to keep stepping.
  function holdRepeat(btn, fn) {
    let t1, t2;
    const stop = () => { clearTimeout(t1); clearInterval(t2); };
    btn.addEventListener("pointerdown", (e) => {
      e.preventDefault(); fn();
      t1 = setTimeout(() => { t2 = setInterval(fn, 90); }, 400);
    });
    ["pointerup", "pointerleave", "pointercancel"].forEach((ev) => btn.addEventListener(ev, stop));
    btn.addEventListener("keydown", (e) => { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); fn(); } });
    btn.addEventListener("contextmenu", (e) => e.preventDefault());
  }

  function toggleRow(key, label, hint) {
    const row = document.createElement("div");
    row.className = "row";
    row.innerHTML = `<div class="label"><span>${label}</span><small>${hint}</small></div>
      <button type="button" class="toggle" role="switch" id="cue-${key}" aria-label="${label}"></button>`;
    const t = row.querySelector("button");
    t.addEventListener("click", () => { cues[key] = !cues[key]; save("tabata.cues", cues); t.setAttribute("aria-checked", cues[key]); });
    t.setAttribute("aria-checked", cues[key]);
    return row;
  }

  function buildSetup() {
    const gi = $("g-intervals"), gr = $("g-rounds"), gc = $("g-cues");
    FIELDS.intervals.forEach((f) => gi.appendChild(stepperRow(f)));
    FIELDS.rounds.forEach((f) => { const r = stepperRow(f); r.dataset.key = f.key; gr.appendChild(r); });
    gc.appendChild(toggleRow("beeps", "Beeps", "3-2-1 countdown and interval changes"));
    gc.appendChild(toggleRow("voice", "Voice", "Announces rounds, work and rest"));
    const pr = $("presets");
    PRESETS.forEach((p, i) => {
      const b = document.createElement("button");
      b.type = "button"; b.className = "chip"; b.dataset.i = i;
      b.innerHTML = `<b>${p.name}</b><small>${p.c.work}/${p.c.rest} × ${p.c.rounds * p.c.sets}</small>`;
      b.addEventListener("click", () => { config = { ...p.c }; save("tabata.config", config); renderSetup(); });
      pr.appendChild(b);
    });
  }

  function renderSetup() {
    [...FIELDS.intervals, ...FIELDS.rounds].forEach((f) => {
      $(`val-${f.key}`).textContent = f.fmt(config[f.key]);
      $(`dec-${f.key}`).disabled = config[f.key] <= f.min;
      $(`inc-${f.key}`).disabled = config[f.key] >= f.max;
    });
    const sr = document.querySelector('#g-rounds [data-key="setRest"]');
    sr.hidden = config.sets <= 1;
    $("total").textContent = clock(totalOf(config));
    $("desc").textContent = `${config.rounds * config.sets} rounds · ${config.work}s work / ${config.rest}s rest`;
    const phases = buildPhases(config), total = totalOf(config);
    $("timeline").innerHTML = phases.map((p) => `<span style="flex:${p.dur / total};background:${COLORS[p.kind]}"></span>`).join("");
    document.querySelectorAll(".chip").forEach((b) => {
      const c = PRESETS[b.dataset.i].c;
      b.setAttribute("aria-pressed", Object.keys(c).every((k) => c[k] === config[k]));
    });
  }

  // ---------- Audio + voice ----------
  let ctx = null;
  function unlockAudio() {
    try {
      if (!ctx) ctx = new (window.AudioContext || window.webkitAudioContext)();
      if (ctx.state === "suspended") ctx.resume();
    } catch { ctx = null; }
  }
  function tone(freq, dur, when = 0, vol = 0.35) {
    if (!cues.beeps || !ctx) return;
    try {
      const t = ctx.currentTime + when, o = ctx.createOscillator(), g = ctx.createGain();
      o.type = "sine"; o.frequency.value = freq;
      g.gain.setValueAtTime(0.0001, t);
      g.gain.exponentialRampToValueAtTime(vol, t + 0.01);
      g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
      o.connect(g).connect(ctx.destination); o.start(t); o.stop(t + dur + 0.02);
    } catch {}
  }
  function say(text) {
    if (!cues.voice || !("speechSynthesis" in window)) return;
    try {
      speechSynthesis.cancel();
      const u = new SpeechSynthesisUtterance(text);
      u.rate = 1.05; speechSynthesis.speak(u);
    } catch {}
  }
  const buzz = (p) => { try { navigator.vibrate && navigator.vibrate(p); } catch {} };

  function announce(p, c) {
    if (p.kind === "work") { tone(1320, 0.45); buzz(200); }
    else { tone(660, 0.45); buzz([80, 60, 80]); }
    const last = p.round === c.rounds && p.set === c.sets;
    say({ prepare: "Get ready", work: last ? "Last round. Work!" : `Round ${p.round}. Work!`, rest: "Rest", setRest: `Set ${p.set} complete. Rest` }[p.kind]);
  }

  // ---------- Workout engine ----------
  let w = null; // active workout
  let wakeLock = null;

  function startWorkout() {
    unlockAudio();
    const c = { ...config }, phases = buildPhases(c);
    const offsets = []; let acc = 0;
    phases.forEach((p) => { offsets.push(acc); acc += p.dur; });
    w = { c, phases, offsets, total: acc, index: 0, state: "running", remaining: phases[0].dur,
          end: Date.now() + phases[0].dur * 1000, completed: 0, startedAt: Date.now(), lastCd: null, saved: false, confirm: false };
    buildWorkoutDom();
    $("workout").hidden = false;
    document.body.style.overflow = "hidden";
    requestWake();
    announce(phases[0], c);
    loop();
  }

  async function requestWake() {
    try { if ("wakeLock" in navigator) wakeLock = await navigator.wakeLock.request("screen"); } catch { wakeLock = null; }
  }
  document.addEventListener("visibilitychange", () => {
    if (document.visibilityState === "visible" && w && w.state === "running") { requestWake(); tick(); }
  });

  let raf = 0, iv = 0;
  function loop() {
    cancelAnimationFrame(raf); clearInterval(iv);
    const f = () => { tick(); if (w && w.state === "running") raf = requestAnimationFrame(f); };
    raf = requestAnimationFrame(f);
    iv = setInterval(tick, 250); // keeps time moving when frames are throttled
  }
  function stopLoop() { cancelAnimationFrame(raf); clearInterval(iv); }

  const elapsed = () => (w.index >= w.phases.length ? w.total : w.offsets[w.index] + (w.phases[w.index].dur - w.remaining));

  function tick() {
    if (!w || w.state !== "running") return;
    const now = Date.now();
    let advanced = false;
    while (now >= w.end) {
      if (w.phases[w.index].kind === "work") w.completed++;
      w.index++;
      if (w.index >= w.phases.length) return finish();
      w.end += w.phases[w.index].dur * 1000;
      w.lastCd = null; advanced = true;
    }
    w.remaining = (w.end - now) / 1000;
    const p = w.phases[w.index];
    if (advanced) announce(p, w.c);
    const sec = Math.ceil(w.remaining);
    if (sec >= 1 && sec <= 3 && p.dur > 3 && sec !== w.lastCd) { w.lastCd = sec; tone(880, 0.15); buzz(40); }
    renderWorkout();
  }

  function togglePause() {
    if (!w) return;
    unlockAudio();
    if (w.state === "running") { tick(); if (w.state !== "running") return; w.state = "paused"; stopLoop(); try { speechSynthesis.cancel(); } catch {} }
    else if (w.state === "paused") { w.end = Date.now() + w.remaining * 1000; w.state = "running"; loop(); }
    renderWorkout();
  }

  function skip() {
    if (!w || (w.state !== "running" && w.state !== "paused")) return;
    w.index++;
    if (w.index >= w.phases.length) return finish();
    const p = w.phases[w.index];
    w.remaining = p.dur; w.lastCd = null;
    if (w.state === "running") w.end = Date.now() + p.dur * 1000;
    announce(p, w.c);
    renderWorkout();
  }

  function finish() {
    stopLoop();
    w.state = "finished"; w.remaining = 0; w.index = w.phases.length;
    tone(1046, 0.18, 0); tone(1318, 0.18, 0.2); tone(1568, 0.5, 0.4); buzz([100, 60, 100, 60, 200]);
    say("Workout complete. Great job!");
    record();
    buildWorkoutDom();
  }

  function endEarly() {
    stopLoop();
    record();
    closeWorkout();
  }

  function closeWorkout() {
    stopLoop();
    try { speechSynthesis.cancel(); } catch {}
    try { wakeLock && wakeLock.release(); } catch {}
    wakeLock = null; w = null;
    $("workout").hidden = true; $("workout").innerHTML = "";
    document.body.style.overflow = "";
  }

  function record() {
    if (!w || w.saved || w.completed === 0) return;
    w.saved = true;
    history.add({
      date: w.startedAt, work: w.c.work, rest: w.c.rest, rounds: w.c.rounds, sets: w.c.sets,
      completed: w.completed, totalRounds: w.c.rounds * w.c.sets, duration: Math.round(elapsed()),
    });
  }

  // ---------- Workout DOM ----------
  const ICON = {
    close: '<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round"><path d="M6 6l12 12M18 6L6 18"/></svg>',
    stop: '<svg viewBox="0 0 24 24" fill="currentColor"><rect x="5" y="5" width="14" height="14" rx="2.5"/></svg>',
    pause: '<svg viewBox="0 0 24 24" fill="currentColor"><rect x="6" y="4.5" width="4" height="15" rx="1.3"/><rect x="14" y="4.5" width="4" height="15" rx="1.3"/></svg>',
    play: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M7 4.5v15l12.5-7.5z"/></svg>',
    skip: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M5 5v14l10-7zM16.5 5h2.5v14h-2.5z"/></svg>',
  };
  const R = 46, CIRC = 2 * Math.PI * R;

  function buildWorkoutDom() {
    const el = $("workout");
    if (w.state === "finished") {
      el.style.backgroundColor = COLORS.done;
      el.innerHTML = `<div class="workout-inner"><div class="summary">
        <svg width="96" height="96" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="10"/><path d="M7.5 12.5l3 3 6-6.5"/></svg>
        <div><h2>Workout complete</h2><p style="margin:8px 0 0;font-weight:600;opacity:.9">Saved to your progress.</p></div>
        <div class="grid">
          <div><b>${clock(w.total)}</b><span>Time</span></div>
          <div><b>${w.completed}/${w.c.rounds * w.c.sets}</b><span>Rounds</span></div>
          <div><b>${clock(w.completed * w.c.work)}</b><span>Work</span></div>
        </div>
      </div><button class="done-btn" id="w-done" type="button">Done</button></div>`;
      $("w-done").addEventListener("click", () => { closeWorkout(); showTab("progress"); });
      return;
    }
    const dots = w.c.rounds <= 20 ? `<div class="dots" id="w-dots">${"<i></i>".repeat(w.c.rounds)}</div>` : "";
    el.innerHTML = `<div class="workout-inner">
      <div class="w-top">
        <button class="icon-btn" id="w-close" type="button" aria-label="End workout">${ICON.close}</button>
        <span class="pill num" id="w-set" ${w.c.sets > 1 ? "" : "hidden"}></span>
      </div>
      <div class="w-main">
        <div class="w-phase" id="w-phase"></div>
        <div class="ring">
          <svg viewBox="0 0 100 100" aria-hidden="true">
            <circle cx="50" cy="50" r="${R}" fill="none" stroke="rgba(255,255,255,.25)" stroke-width="6"/>
            <circle id="w-arc" cx="50" cy="50" r="${R}" fill="none" stroke="#fff" stroke-width="6" stroke-linecap="round" stroke-dasharray="${CIRC}" stroke-dashoffset="${CIRC}"/>
          </svg>
          <div class="clock" id="w-clock" role="timer" aria-live="off"></div>
        </div>
        <div class="w-next" id="w-next"></div>
      </div>
      <div style="display:grid;gap:10px">
        <div class="w-round" id="w-round"></div>
        ${dots}
      </div>
      <div>
        <div class="bar"><div id="w-bar"></div></div>
        <div class="w-times"><span id="w-el"></span><span id="w-left"></span></div>
      </div>
      <div class="controls">
        <button class="ctl sm" id="w-stop" type="button" aria-label="Stop">${ICON.stop}</button>
        <button class="ctl lg" id="w-pause" type="button" aria-label="Pause"></button>
        <button class="ctl sm" id="w-skip" type="button" aria-label="Skip interval">${ICON.skip}</button>
      </div>
    </div>
    <div class="confirm-sheet" id="w-confirm" hidden>
      <div class="confirm-card">
        <h2>End workout?</h2>
        <p id="w-confirm-msg"></p>
        <button class="btn-danger" id="w-end" type="button">End workout</button>
        <button class="btn-plain" id="w-keep" type="button">Keep going</button>
      </div>
    </div>`;
    const ask = () => {
      $("w-confirm-msg").textContent = w.completed > 0
        ? `Your ${w.completed} completed round${w.completed === 1 ? "" : "s"} will be saved.`
        : "No rounds completed yet, so nothing will be saved.";
      $("w-confirm").hidden = false;
    };
    $("w-close").addEventListener("click", ask);
    $("w-stop").addEventListener("click", ask);
    $("w-pause").addEventListener("click", togglePause);
    $("w-skip").addEventListener("click", () => { unlockAudio(); skip(); });
    $("w-end").addEventListener("click", endEarly);
    $("w-keep").addEventListener("click", () => { $("w-confirm").hidden = true; });
    renderWorkout();
  }

  function renderWorkout() {
    if (!w || w.state === "finished") return;
    const p = w.phases[w.index], paused = w.state === "paused";
    $("workout").style.backgroundColor = paused ? COLORS.paused : COLORS[p.kind];
    $("w-phase").textContent = paused ? "Paused" : TITLES[p.kind];
    $("w-clock").textContent = clock(Math.ceil(w.remaining - 1e-6));
    const prog = p.dur > 0 ? Math.min(1, Math.max(0, 1 - w.remaining / p.dur)) : 1;
    $("w-arc").setAttribute("stroke-dashoffset", CIRC * (1 - prog));
    const n = w.phases[w.index + 1];
    $("w-next").textContent = n ? `Next: ${TITLES[n.kind]} · ${n.dur}s` : "Last interval";
    $("w-round").textContent = p.kind === "prepare" ? `${w.c.rounds * w.c.sets} rounds ahead` : `Round ${p.round} of ${w.c.rounds}`;
    $("w-set").textContent = `Set ${p.set} of ${w.c.sets}`;
    const dots = $("w-dots");
    if (dots) [...dots.children].forEach((d, i) => {
      const r = i + 1, active = p.kind !== "prepare";
      d.className = !active ? "" : r < p.round || (r === p.round && p.kind !== "work") ? "on" : r === p.round ? "cur" : "";
    });
    const el = elapsed();
    $("w-bar").style.width = `${Math.min(100, (el / w.total) * 100)}%`;
    $("w-el").textContent = `${clock(Math.floor(el))} elapsed`;
    $("w-left").textContent = `${clock(Math.ceil(w.total - el))} left`;
    const pb = $("w-pause");
    pb.innerHTML = paused ? ICON.play : ICON.pause;
    pb.style.color = paused ? COLORS.paused : COLORS[p.kind];
    pb.setAttribute("aria-label", paused ? "Resume" : "Pause");
  }

  // ---------- History store ----------
  // Workouts are kept on this device. Installed web apps keep their storage;
  // Export/Import in the Progress tab moves it between devices.
  const history = {
    items: [],
    load() { try { this.items = JSON.parse(localStorage.getItem("tabata.history") || "[]"); } catch { this.items = []; } },
    persist() { try { localStorage.setItem("tabata.history", JSON.stringify(this.items)); } catch {} },
    add(rec) { this.items.unshift({ id: "w" + Date.now().toString(36), ...rec }); this.persist(); renderProgress(); },
    remove(id) { this.items = this.items.filter((i) => i.id !== id); this.persist(); renderProgress(); },
    merge(list) {
      const seen = new Set(this.items.map((i) => i.id));
      let added = 0;
      for (const it of list) {
        if (!it || typeof it.date !== "number" || typeof it.duration !== "number" || seen.has(it.id)) continue;
        this.items.push({
          id: String(it.id || "w" + it.date.toString(36)), date: it.date, duration: it.duration,
          work: +it.work || 0, rest: +it.rest || 0, rounds: +it.rounds || 0, sets: +it.sets || 1,
          completed: +it.completed || 0, totalRounds: +it.totalRounds || 0,
        });
        added++;
      }
      this.items.sort((a, b) => b.date - a.date); this.persist(); renderProgress();
      return added;
    },
  };

  async function exportHistory() {
    const json = JSON.stringify({ app: "tabata", version: 1, workouts: history.items }, null, 2);
    const name = `tabata-history-${new Date().toISOString().slice(0, 10)}.json`;
    const file = new File([json], name, { type: "application/json" });
    try {
      if (navigator.canShare && navigator.canShare({ files: [file] })) { await navigator.share({ files: [file], title: "Tabata history" }); return; }
    } catch (e) { if (e && e.name === "AbortError") return; }
    const a = document.createElement("a");
    a.href = URL.createObjectURL(file); a.download = name;
    document.body.appendChild(a); a.click(); a.remove();
    setTimeout(() => URL.revokeObjectURL(a.href), 1000);
  }

  function importHistory(file) {
    const r = new FileReader();
    r.onload = () => {
      let msg;
      try {
        const data = JSON.parse(r.result);
        const n = history.merge(Array.isArray(data) ? data : data.workouts || []);
        msg = n ? `Imported ${n} workout${n === 1 ? "" : "s"}.` : "No new workouts found in that file.";
      } catch { msg = "That file isn't a Tabata history export."; }
      $("sync").textContent = msg;
    };
    r.readAsText(file);
  }

  // ---------- Progress view ----------
  const dayStart = (t) => { const d = new Date(t); d.setHours(0, 0, 0, 0); return d.getTime(); };
  const addDays = (t, n) => { const d = new Date(t); d.setDate(d.getDate() + n); return dayStart(d); };

  function streak(items) {
    const days = new Set(items.map((i) => dayStart(i.date)));
    let d = dayStart(Date.now());
    if (!days.has(d)) { d = addDays(d, -1); if (!days.has(d)) return 0; }
    let n = 0; while (days.has(d)) { n++; d = addDays(d, -1); }
    return n;
  }

  function chartSvg(items) {
    const today = dayStart(Date.now());
    const days = Array.from({ length: 7 }, (_, i) => addDays(today, i - 6));
    const mins = days.map((d) => items.filter((i) => dayStart(i.date) === d).reduce((a, i) => a + i.duration, 0) / 60);
    const peak = Math.max(...mins);
    const top = peak <= 5 ? 5 : peak <= 10 ? 10 : Math.ceil(peak / 10) * 10;
    const W = 340, H = 182, L = 30, B = 26, T = 22, plotH = H - B - T, plotW = W - L - 6, slot = plotW / 7, bw = slot * 0.56;
    const y = (v) => T + plotH - (v / top) * plotH;
    const ticks = [0, top / 2, top];
    let s = `<svg viewBox="0 0 ${W} ${H}" role="img" aria-label="Minutes trained per day, last 7 days">`;
    ticks.forEach((t) => {
      s += `<line x1="${L}" x2="${W - 4}" y1="${y(t)}" y2="${y(t)}" stroke="var(--line)" stroke-width="1"/>`;
      s += `<text x="${L - 6}" y="${y(t) + 4}" text-anchor="end" font-size="11" fill="var(--ink-2)" font-family="Barlow, sans-serif">${Math.round(t * 10) / 10}</text>`;
    });
    days.forEach((d, i) => {
      const x = L + i * slot + (slot - bw) / 2, v = mins[i], h = (v / top) * plotH;
      if (v > 0) s += `<rect x="${x}" y="${y(v)}" width="${bw}" height="${Math.max(h, 2)}" rx="4" fill="${d === today ? "var(--work)" : "var(--ink)"}" opacity="${d === today ? 1 : 0.8}"><title>${Math.round(v * 10) / 10} min</title></rect>`;
      const lbl = new Date(d).toLocaleDateString(undefined, { weekday: "short" });
      s += `<text x="${x + bw / 2}" y="${H - 8}" text-anchor="middle" font-size="11.5" font-weight="${d === today ? 700 : 500}" fill="${d === today ? "var(--ink)" : "var(--ink-2)"}" font-family="Barlow, sans-serif">${lbl}</text>`;
    });
    s += `<text x="${L - 6}" y="11" text-anchor="end" font-size="10" fill="var(--ink-2)" font-family="Barlow, sans-serif">min</text>`;
    return s + "</svg>";
  }

  let pendingDelete = null;
  function renderProgress() {
    const items = history.items.slice().sort((a, b) => b.date - a.date);
    const body = $("progress-body");
    if (!items.length) {
      body.innerHTML = `<div class="empty"><b>No workouts yet</b>Finish a workout, or end one after at least one round, and it shows up here.</div>`;
      return;
    }
    const totalTime = items.reduce((a, i) => a + i.duration, 0);
    const rounds = items.reduce((a, i) => a + i.completed, 0);
    const now = new Date(), wkStart = addDays(dayStart(now), -((now.getDay() + 6) % 7));
    const week = items.filter((i) => i.date >= wkStart).length;
    const done = items.filter((i) => i.completed >= i.totalRounds).length;
    body.innerHTML = `
      <div class="view">
        <div class="stats">
          <div class="stat"><b>${items.length}</b><span>Workouts</span></div>
          <div class="stat"><b>${streak(items)}</b><span>Day streak</span></div>
          <div class="stat"><b>${week}</b><span>This week</span></div>
          <div class="stat"><b>${clock(totalTime)}</b><span>Total time</span></div>
          <div class="stat"><b>${rounds}</b><span>Rounds</span></div>
          <div class="stat"><b>${Math.round((done / items.length) * 100)}%</b><span>Completed</span></div>
        </div>
        <div><p class="eyebrow">Last 7 days</p><div class="chart">${chartSvg(items)}</div></div>
        <div><p class="eyebrow">History</p><div class="list">${items.map((i) => {
          const full = i.completed >= i.totalRounds;
          const when = new Date(i.date).toLocaleString(undefined, { weekday: "short", day: "numeric", month: "short", hour: "numeric", minute: "2-digit" });
          return `<div class="item">
            <span class="dot" style="background:${full ? "var(--done)" : "var(--prep)"}" title="${full ? "Completed" : "Ended early"}"></span>
            <div class="meta"><b>${when}</b><small>${i.work}s / ${i.rest}s · ${i.completed}/${i.totalRounds} rounds${full ? "" : " · ended early"}</small></div>
            <span class="dur">${clock(i.duration)}</span>
            <button type="button" class="del${pendingDelete === i.id ? " confirm" : ""}" data-id="${i.id}">${pendingDelete === i.id ? "Delete?" : "Remove"}</button>
          </div>`;
        }).join("")}</div></div>
      </div>`;
    body.querySelectorAll(".del").forEach((b) => b.addEventListener("click", () => {
      const id = b.dataset.id;
      if (pendingDelete === id) { pendingDelete = null; history.remove(id); }
      else { pendingDelete = id; renderProgress(); }
    }));
  }

  // ---------- Tabs ----------
  function showTab(name) {
    const t = name === "timer";
    $("view-timer").hidden = !t; $("view-progress").hidden = t; $("start").hidden = !t;
    $("app").classList.toggle("timer-tab", t);
    $("tab-timer").setAttribute("aria-selected", t); $("tab-progress").setAttribute("aria-selected", !t);
    pendingDelete = null;
    if (!t) renderProgress();
    window.scrollTo(0, 0);
  }
  $("tab-timer").addEventListener("click", () => showTab("timer"));
  $("tab-progress").addEventListener("click", () => showTab("progress"));
  $("start").addEventListener("click", startWorkout);

  buildSetup();
  renderSetup();
  history.load();
  renderProgress();
  $("export").addEventListener("click", exportHistory);
  $("import").addEventListener("click", () => $("import-file").click());
  $("import-file").addEventListener("change", (e) => { const f = e.target.files[0]; if (f) importHistory(f); e.target.value = ""; });

  // Ask the browser not to evict saved workouts under storage pressure.
  try { navigator.storage && navigator.storage.persist && navigator.storage.persist(); } catch {}

  if ("serviceWorker" in navigator && location.protocol !== "file:") {
    window.addEventListener("load", () => navigator.serviceWorker.register("sw.js").catch(() => {}));
  }
})();
