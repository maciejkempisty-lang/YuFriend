"use strict";
(() => {
  const M = globalThis.YF, FS = globalThis.YF_FS;
  const {LAYERS, SCRIPTS, SCRIPT_OPTIONS, CLIPS, clone, id, newLevel, newElement, ordered, rect, removeLevel, validate, migrate, setScript, isInteractive} = M;

  const $ = s => document.querySelector(s);
  const el = (tag, cls, text) => { const n = document.createElement(tag); if (cls) n.className = cls; if (text !== undefined) n.textContent = text; return n; };

  let project, levelId, selected = null, activeLayer = 'middle', dirty = false;
  let history = [], future = [];
  const images = new Map(), blobBySource = new Map();
  let filter = '', fileName = 'moj-projekt.json', diskAssets = [];
  let zoom = 1, pan = {x: 0, y: 0}, drag = null, hidden = new Set();
  let testing = false, testState = null, lastTime = 0, autosaveTimer;

  const canvas = $('#canvas'), ctx = canvas.getContext('2d'), stage = $('#stage');
  const level = () => project?.levels.find(l => l.id === levelId);
  const item = () => level()?.elements.find(e => e.id === selected);
  const asset = key => project.assets.find(a => a.id === key);
  const source = a => blobBySource.get(a.source) || a.source;

  function question(message, value, mode = 'prompt') {
    return new Promise(resolve => {
      const dialog = $('#questionDialog');
      $('#questionText').textContent = message;
      $('#questionInput').hidden = mode !== 'prompt';
      $('#questionInput').value = value || '';
      $('#questionCancel').hidden = mode === 'info';
      dialog.returnValue = '';
      dialog.addEventListener('close', () => resolve(dialog.returnValue === 'ok' ? (mode === 'prompt' ? $('#questionInput').value : true) : (mode === 'prompt' ? null : false)), {once: true});
      dialog.showModal();
    });
  }
  const ask = (message, value) => question(message, value);
  const confirmAction = message => question(message, '', 'confirm');
  const inform = message => question(message, '', 'info');

  function status(text, error = false) {
    $('#status').textContent = text;
    $('#status').style.color = error ? '#eda998' : '';
  }
  function checkpoint() { history.push(clone(project)); if (history.length > 50) history.shift(); future = []; }
  function changed(text = 'Zmiany niezapisane') {
    dirty = true; $('#dirty').textContent = '● Niezapisane'; status(text);
    clearTimeout(autosaveTimer);
    autosaveTimer = setTimeout(() => {
      try { localStorage.setItem('yufriend-editor-draft', JSON.stringify(project)); }
      catch { status('Projekt jest w pamięci. Zapisz JSON — kopia przeglądarki jest pełna.'); }
    }, 500);
  }
  function saved() {
    dirty = false; $('#dirty').textContent = 'Zapisany';
    try { localStorage.removeItem('yufriend-editor-draft'); } catch {}
  }
  function valid() {
    const errors = validate(project);
    if (errors.length) { inform('Popraw projekt przed zapisem:\n' + errors.slice(0, 12).join('\n')); return false; }
    return true;
  }
  function mutate(fn, text) { checkpoint(); fn(); changed(text); render(); }
  function undo(redo = false) {
    const from = redo ? future : history, to = redo ? history : future;
    if (!from.length || testing) return;
    to.push(clone(project)); project = from.pop();
    if (!project.levels.some(l => l.id === levelId)) levelId = project.startLevel;
    selected = null; loadImages(); changed(); render();
  }

  async function cacheBlob(a) {
    if (!a?.source || blobBySource.has(a.source)) return;
    const url = await FS.resolveSource(a.source);
    if (url) blobBySource.set(a.source, url);
  }
  async function cacheAll(list) { await Promise.all(list.map(cacheBlob)); }

  async function loadImages() {
    await cacheAll(project.assets);
    await Promise.all(project.assets.map(async a => {
      const src = source(a);
      if (images.get(a.id)?.src === src) return;
      const img = new Image();
      try { img.src = src; await img.decode(); images.set(a.id, {src, img}); }
      catch { images.delete(a.id); status(`Nie można odczytać grafiki: ${a.name}`, true); }
    }));
    draw();
  }
  async function refreshDiskAssets() {
    if (!FS.hasRoot()) { diskAssets = []; return; }
    try {
      diskAssets = await FS.scanAssets();
      await cacheAll(diskAssets);
    } catch (e) { status('Nie udało się przeskanować folderu assets/: ' + e.message, true); diskAssets = []; }
  }
  async function acceptProject(raw) {
    const p = migrate(raw);
    const errors = validate(p);
    if (errors.length) throw Error(errors.slice(0, 10).join('\n'));
    project = p; levelId = p.startLevel; selected = null; history = []; future = [];
    images.clear(); stopTest(); saved();
    await refreshDiskAssets();
    await loadImages(); fit(); render();
    const extra = diskAssets.filter(d => !project.assets.some(a => a.id === d.id)).length;
    status(extra ? `Projekt wczytany. ${extra} nowych grafik w folderze assets/.` : 'Projekt wczytany.');
  }
  function fit() { zoom = 1; pan = {x: 0, y: 0}; draw(); }
  function transform() {
    const l = level(), w = stage.clientWidth, h = stage.clientHeight;
    const base = Math.min((w - 60) / l.width, (h - 100) / l.height);
    const scale = Math.max(.02, base * zoom);
    return {scale, x: (w - l.width * scale) / 2 + pan.x, y: (h - l.height * scale) / 2 + pan.y};
  }
  function worldPoint(ev) {
    const r = canvas.getBoundingClientRect(), t = transform();
    return {x: (ev.clientX - r.left - t.x) / t.scale, y: (ev.clientY - r.top - t.y) / t.scale};
  }
  function snapN(n) { return $('#snap').checked ? Math.round(n / 3) * 3 : Math.round(n * 10) / 10; }

  function overlayBubble(kind, text, worldX, worldY) {
    if (!text) return;
    const t = transform();
    const sx = worldX * t.scale + t.x, sy = worldY * t.scale + t.y;
    ctx.save(); ctx.setTransform(1, 0, 0, 1, 0, 0);
    const padX = 12, padY = 8, maxWidth = 260;
    ctx.font = '13px system-ui';
    const lines = wrapLines(text, maxWidth - padX * 2);
    const lineH = 17, w = Math.min(maxWidth, Math.max(...lines.map(l => ctx.measureText(l).width)) + padX * 2);
    const h = lines.length * lineH + padY * 2;
    const bx = Math.round(sx - w / 2), by = Math.round(sy - h - 24);
    if (kind === 'thought') drawCloud(bx, by, w, h, sx, sy - 10);
    else { drawRoundRect(bx, by, w, h, 10, '#edf0d9', '#243c29'); drawTail(sx, sy - 14, sx - 6, by + h, sx + 6, by + h, '#edf0d9'); }
    ctx.fillStyle = '#243c29'; ctx.textBaseline = 'top';
    for (let i = 0; i < lines.length; i++) ctx.fillText(lines[i], bx + padX, by + padY + i * lineH);
    ctx.restore();
  }
  function wrapLines(text, maxWidth) {
    const words = String(text).split(/\s+/); const lines = []; let cur = '';
    for (const w of words) {
      const t = cur ? cur + ' ' + w : w;
      if (ctx.measureText(t).width > maxWidth && cur) { lines.push(cur); cur = w; } else cur = t;
    }
    if (cur) lines.push(cur);
    return lines.slice(0, 5);
  }
  function drawRoundRect(x, y, w, h, r, fill, stroke) {
    ctx.beginPath();
    ctx.moveTo(x + r, y); ctx.arcTo(x + w, y, x + w, y + h, r); ctx.arcTo(x + w, y + h, x, y + h, r);
    ctx.arcTo(x, y + h, x, y, r); ctx.arcTo(x, y, x + w, y, r); ctx.closePath();
    ctx.fillStyle = fill; ctx.fill();
    if (stroke) { ctx.strokeStyle = stroke; ctx.lineWidth = 1; ctx.stroke(); }
  }
  function drawTail(tipX, tipY, ax, ay, bx, by, fill) {
    ctx.beginPath(); ctx.moveTo(tipX, tipY); ctx.lineTo(ax, ay); ctx.lineTo(bx, by); ctx.closePath();
    ctx.fillStyle = fill; ctx.fill();
  }
  function drawCloud(x, y, w, h, tipX, tipY) {
    ctx.fillStyle = '#f6f6ec'; ctx.strokeStyle = '#243c29'; ctx.lineWidth = 1;
    const r = Math.min(h / 2, 22);
    ctx.beginPath();
    const bumps = Math.max(3, Math.round(w / 40));
    for (let i = 0; i <= bumps; i++) ctx.arc(x + (w * i) / bumps, y + r * 0.6, r * 0.9, 0, Math.PI * 2);
    for (let i = 0; i <= bumps; i++) ctx.arc(x + (w * i) / bumps, y + h - r * 0.6, r * 0.9, 0, Math.PI * 2);
    ctx.arc(x - 2, y + h / 2, r * 0.9, 0, Math.PI * 2);
    ctx.arc(x + w + 2, y + h / 2, r * 0.9, 0, Math.PI * 2);
    ctx.fill(); ctx.stroke();
    ctx.beginPath(); ctx.arc(tipX, tipY - 6, 5, 0, Math.PI * 2); ctx.fillStyle = '#f6f6ec'; ctx.fill(); ctx.stroke();
    ctx.beginPath(); ctx.arc(tipX - 6, tipY + 2, 3, 0, Math.PI * 2); ctx.fill(); ctx.stroke();
  }

  function draw() {
    if (!project) return;
    const dpr = devicePixelRatio || 1, w = stage.clientWidth, h = stage.clientHeight;
    if (canvas.width !== Math.round(w * dpr) || canvas.height !== Math.round(h * dpr)) {
      canvas.width = Math.round(w * dpr); canvas.height = Math.round(h * dpr);
    }
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0); ctx.clearRect(0, 0, w, h);
    const l = level(), t = transform();
    ctx.translate(t.x, t.y); ctx.scale(t.scale, t.scale); ctx.imageSmoothingEnabled = false;
    ctx.fillStyle = '#c2c8aa'; ctx.fillRect(0, 0, l.width, l.height);
    ctx.save(); ctx.beginPath(); ctx.rect(0, 0, l.width, l.height); ctx.clip();
    const list = ordered(l).map(e => testing && testState.balls[e.id] ? {...e, ...testState.balls[e.id]} : e);
    if (testing) list.push({actor: true, layer: 'middle', y: testState.dog.y, _order: 1e5});
    list.sort((a, b) => LAYERS.indexOf(a.layer) - LAYERS.indexOf(b.layer) || (a.layer === 'middle' ? a.y - b.y : 0) || a._order - b._order);
    for (const e of list) {
      if (e.actor) { drawDog(testState.dog); continue; }
      if (!e.visible || (!testing && hidden.has(e.layer))) continue;
      const a = asset(e.asset), image = images.get(a.id)?.img;
      const pos = testing && testState.balls[e.id] ? {...e, ...testState.balls[e.id]} : e;
      const r = rect(pos, a);
      if (image) ctx.drawImage(image, r.x, r.y, r.width, r.height);
      else { ctx.fillStyle = '#a84b73'; ctx.fillRect(r.x, r.y, r.width, r.height); }
    }
    if (!testing) {
      if ($('#grid').checked) {
        ctx.strokeStyle = '#1d3d292c'; ctx.lineWidth = 1 / t.scale; ctx.beginPath();
        for (let x = 0; x <= l.width; x += 24) { ctx.moveTo(x, 0); ctx.lineTo(x, l.height); }
        for (let y = 0; y <= l.height; y += 24) { ctx.moveTo(0, y); ctx.lineTo(l.width, y); }
        ctx.stroke();
      }
      ctx.fillStyle = '#b4edab28'; ctx.fillRect(l.walk.x, l.walk.y, l.walk.width, l.walk.height);
      ctx.strokeStyle = '#d6f4b3'; ctx.lineWidth = 1 / t.scale; ctx.setLineDash([6 / t.scale, 4 / t.scale]);
      ctx.strokeRect(l.walk.x, l.walk.y, l.walk.width, l.walk.height); ctx.setLineDash([]);
      ctx.fillStyle = '#203d2e'; ctx.beginPath(); ctx.arc(l.spawn.x, l.spawn.y, 6 / t.scale, 0, Math.PI * 2); ctx.fill();
      ctx.fillStyle = '#edf6d8'; ctx.font = `${11 / t.scale}px system-ui`;
      ctx.fillText('START', l.spawn.x + 10 / t.scale, l.spawn.y + 4 / t.scale);
      const e = item();
      if (e && e.visible && !hidden.has(e.layer)) {
        const r = rect(e, asset(e.asset));
        ctx.strokeStyle = '#f5e19a'; ctx.lineWidth = 2 / t.scale; ctx.strokeRect(r.x, r.y, r.width, r.height);
        ctx.fillStyle = '#f5e19a'; ctx.beginPath(); ctx.arc(e.x, e.y, 4 / t.scale, 0, Math.PI * 2); ctx.fill();
        ctx.font = `${12 / t.scale}px system-ui`;
        ctx.fillText(e.name + (SCRIPTS[e.script]?.icon ? '  ' + SCRIPTS[e.script].icon : ''), r.x, r.y - 9 / t.scale);
      }
    }
    ctx.restore();
    ctx.strokeStyle = '#7b8d6e'; ctx.lineWidth = 1 / t.scale; ctx.strokeRect(0, 0, l.width, l.height);
    $('#zoomLabel').textContent = Math.round(zoom * 100) + '%';
    if (!testing) {
      const e = item();
      if (e) {
        if (e.script === 'message' && e.params?.text) overlayBubble('message', e.params.text, e.x, e.y - (e.pivot?.y || 0) * (e.height / asset(e.asset).height));
        else if (e.script === 'thought' && e.params?.text) overlayBubble('thought', e.params.text, e.x, e.y - 60);
      }
    } else if (testState.bubble) {
      const b = testState.bubble;
      overlayBubble(b.kind, b.text, b.x, b.y);
    }
  }

  const dogImage = new Image();
  async function initDogImage() {
    const url = await FS.resolveSource('res://level-editor/assets/puppy.png');
    if (url) { dogImage.onload = draw; dogImage.src = url; }
  }
  function drawDog(p) {
    if (dogImage.complete && dogImage.naturalWidth) ctx.drawImage(dogImage, p.x - 144, p.y - 240, 288, 288);
    else { ctx.fillStyle = '#e0a75d'; ctx.beginPath(); ctx.ellipse(p.x, p.y - 35, 35, 35, 0, 0, 7); ctx.fill(); }
  }

  function render() {
    if (!project) return;
    $('#projectName').value = project.name;
    $('#undo').disabled = !history.length || testing;
    $('#redo').disabled = !future.length || testing;
    $('#levelTitle').textContent = level().name;
    $('#dimensions').textContent = `${level().width} × ${level().height}`;
    $('#count').textContent = `${level().elements.length} elementów`;
    $('#deleteLevel').disabled = project.levels.length <= 1;
    $('#duplicateItem').disabled = $('#deleteItem').disabled = !item();
    $('#rootName').textContent = FS.rootName() || '—';
    $('#saveRepo').disabled = !FS.hasRoot();

    const levels = $('#levels'); levels.replaceChildren();
    for (const l of project.levels) {
      const b = el('button', 'level' + (l.id === levelId ? ' selected' : ''));
      b.append(el('span', '', l.name), el('small', '', l.id === project.startLevel ? 'START' : `${l.elements.length}`));
      b.onclick = () => { if (testing) return; levelId = l.id; selected = null; fit(); render(); };
      levels.append(b);
    }
    const layers = $('#layers'); layers.replaceChildren();
    for (const key of [...LAYERS].reverse()) {
      const row = el('div', 'layer');
      const b = el('button', activeLayer === key ? 'selected' : '', {background: 'Background', middle: 'Middle ground', foreground: 'Foreground'}[key]);
      b.onclick = () => { activeLayer = key; render(); };
      const eye = el('button', '', hidden.has(key) ? 'Pokaż' : 'Ukryj');
      eye.title = 'Tylko podgląd w edytorze';
      eye.onclick = () => { hidden.has(key) ? hidden.delete(key) : hidden.add(key); render(); };
      row.append(b, eye); layers.append(row);
    }
    const list = $('#elements'); list.replaceChildren();
    for (const e of [...level().elements].reverse().filter(e => e.layer === activeLayer)) {
      const b = el('button', 'element' + (e.id === selected ? ' selected' : ''));
      const img = el('img'); img.src = source(asset(e.asset)); img.alt = '';
      const icon = SCRIPTS[e.script]?.icon || '';
      b.append(img, el('span', '', e.name), el('small', '', e.locked ? '▣' : (isInteractive(e) ? icon : '')));
      b.onclick = () => { selected = e.id; render(); };
      list.append(b);
    }
    if (!list.childElementCount) list.append(el('p', 'note', 'Ta warstwa jest jeszcze pusta.'));
    const lib = $('#assets'); lib.replaceChildren();
    const diskOnly = diskAssets.filter(d => !project.assets.some(a => a.id === d.id));
    const unified = [...project.assets, ...diskOnly];
    const visible = unified.filter(a => a.name.toLowerCase().includes(filter) || a.id.toLowerCase().includes(filter));
    for (const a of visible) {
      const inProject = project.assets.some(x => x.id === a.id);
      const b = el('button', 'asset' + (inProject ? '' : ' disk-only'));
      const img = el('img'); img.src = source(a); img.alt = '';
      b.title = `${a.name} · ${a.width} × ${a.height} px · ${inProject ? 'w projekcie' : 'w folderze assets/'}`;
      b.append(img, el('span', '', a.name));
      if (!inProject) b.append(el('small', 'badge', '+ dodaj'));
      b.onclick = async () => {
        // Thumbnails use the file URL directly, while the canvas uses this
        // decoded-image cache. Load a disk asset before putting it on scene.
        const src = source(a);
        if (images.get(a.id)?.src !== src) {
          const sceneImage = new Image();
          try {
            sceneImage.src = src;
            await sceneImage.decode();
            images.set(a.id, {src, img: sceneImage});
          } catch {
            status(`Nie można odczytać grafiki: ${a.name}`, true);
            return;
          }
        }
        mutate(() => {
          let used = project.assets.find(x => x.id === a.id);
          if (!used) { used = {id: a.id, name: a.name, source: a.source, width: a.width, height: a.height}; project.assets.push(used); }
          const e = newElement(used, activeLayer);
          e.x = snapN(level().width / 2); e.y = snapN(level().walk.y + level().walk.height / 2);
          level().elements.push(e); selected = e.id;
        }, inProject ? 'Dodano element.' : 'Dodano nową grafikę z folderu.');
      };
      lib.append(b);
    }
    if (!visible.length) lib.append(el('p', 'note', FS.hasRoot()
      ? 'Brak grafik. Wrzuć PNG do folderu level-editor/assets/ i kliknij ↻.'
      : 'Wskaż folder YuFriend, aby zobaczyć grafiki na dysku.'));
    inspector(); draw();
  }

  function field(parent, label, value, update, options) {
    const wrap = el('label', 'field'); wrap.append(el('span', '', label));
    let input;
    if (options) {
      input = el('select');
      for (const [v, n] of Object.entries(options)) { const o = el('option', '', n); o.value = v; input.append(o); }
    } else {
      const isMultiline = ['Komunikat', 'Treść', 'Myśl psa', 'Komunikat przy wejściu', 'Komunikat (opcja)'].includes(label);
      input = el(isMultiline ? 'textarea' : 'input');
      if (typeof value === 'number') { input.type = 'number'; input.step = 'any'; }
    }
    input.value = value;
    input.onchange = () => {
      const v = typeof value === 'number' ? Number(input.value) : input.value;
      if (typeof v === 'number' && !Number.isFinite(v)) return;
      mutate(() => update(v));
    };
    wrap.append(input); parent.append(wrap);
    return input;
  }
  function check(parent, label, value, update) {
    const wrap = el('label', 'check'), input = el('input'); input.type = 'checkbox'; input.checked = value;
    input.onchange = () => mutate(() => update(input.checked));
    wrap.append(input, document.createTextNode(label)); parent.append(wrap);
  }
  function pair(parent, fields) { const row = el('div', 'pair'); for (const f of fields) field(row, ...f); parent.append(row); }
  function heading(parent, text) { parent.append(el('div', 'group-title', text)); }

  function paramInput(parent, key, schemaDef, element) {
    const label = schemaDef.label || key;
    const value = element.params?.[key] ?? (schemaDef.default ?? '');
    const update = v => { if (!element.params) element.params = {}; element.params[key] = v; };
    if (schemaDef.type === 'level') {
      field(parent, label, value, update, Object.fromEntries(project.levels.map(l => [l.id, l.name])));
    } else if (schemaDef.type === 'clip') {
      const wrap = el('label', 'field'); wrap.append(el('span', '', label));
      const input = el('input'); input.value = value; input.setAttribute('list', 'clip-list');
      input.onchange = () => mutate(() => update(input.value));
      wrap.append(input); parent.append(wrap);
    } else if (schemaDef.type === 'bool') {
      check(parent, label, value === true, update);
    } else if (schemaDef.type === 'number') {
      field(parent, label, Number(value), update);
    } else {
      field(parent, label, String(value), update);
    }
  }

  function ensureClipDatalist() {
    if (document.getElementById('clip-list')) return;
    const dl = document.createElement('datalist'); dl.id = 'clip-list';
    for (const c of CLIPS) { const o = document.createElement('option'); o.value = c; dl.append(o); }
    document.body.append(dl);
  }

  function inspector() {
    ensureClipDatalist();
    const box = $('#inspector'); box.replaceChildren();
    const e = item(), l = level();
    $('#inspectorTitle').textContent = e ? 'Element' : 'Poziom';
    if (!e) {
      field(box, 'Nazwa poziomu', l.name, v => l.name = v);
      pair(box, [['Szerokość', l.width, v => l.width = v], ['Wysokość', l.height, v => l.height = v]]);
      check(box, 'Poziom startowy', project.startLevel === l.id, v => { if (v) project.startLevel = l.id; });
      heading(box, 'START PSA');
      pair(box, [['X', l.spawn.x, v => l.spawn.x = v], ['Y', l.spawn.y, v => l.spawn.y = v]]);
      heading(box, 'PAS RUCHU');
      pair(box, [['X', l.walk.x, v => l.walk.x = v], ['Y', l.walk.y, v => l.walk.y = v]]);
      pair(box, [['Szerokość pasa', l.walk.width, v => l.walk.width = v], ['Wysokość pasa', l.walk.height, v => l.walk.height = v]]);
      heading(box, 'PRĘDKOŚCI PSA');
      pair(box, [['Chód (px/s)', l.walkSpeed, v => l.walkSpeed = v], ['Bieg (px/s)', l.runSpeed, v => l.runSpeed = v]]);
      box.append(el('p', 'note', 'Zielony pas to obszar poruszania się psa. Prędkości działają w edytorze i w grze.'));
      return;
    }
    field(box, 'Nazwa', e.name, v => e.name = v);
    field(box, 'Warstwa', e.layer, v => { e.layer = v; activeLayer = v; }, {background: 'Background', middle: 'Middle ground · Y-sort', foreground: 'Foreground'});
    heading(box, 'POŁOŻENIE I ROZMIAR');
    pair(box, [['X podstawy', e.x, v => e.x = v], ['Y podstawy', e.y, v => e.y = v]]);
    pair(box, [['Szerokość', e.width, v => e.width = v], ['Wysokość', e.height, v => e.height = v]]);
    heading(box, 'PODSTAWA W PIKSELACH PNG');
    pair(box, [['Pivot X', e.pivot.x, v => e.pivot.x = v], ['Pivot Y', e.pivot.y, v => e.pivot.y = v]]);
    box.append(el('p', 'note', 'Punkt podparcia wyznacza głębokość. Rozmiar sceny w jednostkach świata, podstawa w pikselach grafiki.'));
    check(box, 'Widoczny w grze', e.visible, v => e.visible = v);
    check(box, 'Zablokuj w edytorze', e.locked, v => e.locked = v);
    const forced = SCRIPTS[e.script]?.static;
    if (typeof forced === 'boolean') {
      box.append(el('p', 'note', `Skrypt „${SCRIPTS[e.script].label}” wymusza static=${forced}.`));
    } else {
      check(box, 'Statyczny', e.static, v => e.static = v);
    }
    heading(box, 'SKRYPT');
    field(box, 'Rodzaj', e.script, v => setScript(e, v, project), SCRIPT_OPTIONS);
    const schema = SCRIPTS[e.script]?.params || {};
    if (Object.keys(schema).length) {
      heading(box, 'PARAMETRY SKRYPTU');
      for (const [key, def] of Object.entries(schema)) paramInput(box, key, def, e);
    } else if (e.script === 'none') {
      box.append(el('p', 'note', 'Element dekoracyjny. Zmień rodzaj skryptu, aby ożywić go w grze.'));
    }
    const row = el('div', 'inline');
    for (const [label, direction] of [['Niżej', -1], ['Wyżej', 1]]) {
      const b = el('button', '', label);
      b.onclick = () => mutate(() => {
        const arr = l.elements, i = arr.indexOf(e), j = i + direction;
        if (j >= 0 && j < arr.length) [arr[i], arr[j]] = [arr[j], arr[i]];
      });
      row.append(b);
    }
    box.append(row, el('p', 'note', e.layer === 'middle' ? 'W tej warstwie pozycja Y ma pierwszeństwo przed kolejnością na liście.' : 'Kolejność na liście rozstrzyga zasłanianie w tej warstwie.'));
  }

  function hit(p, interactive = false) {
    return ordered(level()).reverse().find(e => {
      if (!e.visible || (!testing && hidden.has(e.layer)) || (interactive && !isInteractive(e))) return false;
      const r = rect(testing && testState.balls[e.id] ? {...e, ...testState.balls[e.id]} : e, asset(e.asset));
      return p.x >= r.x && p.x <= r.x + r.width && p.y >= r.y && p.y <= r.y + r.height;
    });
  }

  canvas.onpointerdown = ev => {
    if (!project) return;
    canvas.focus(); canvas.setPointerCapture(ev.pointerId);
    const p = worldPoint(ev);
    if (testing) {
      const e = hit(p, true);
      if (e?.script === 'ball') drag = {ball: e.id, start: p};
      else activate(e, p);
      return;
    }
    if (ev.altKey || ev.button === 1) { drag = {pan: true, x: ev.clientX, y: ev.clientY, origin: {...pan}}; return; }
    const e = hit(p); selected = e?.id || null;
    if (e) {
      activeLayer = e.layer;
      if (!e.locked) { checkpoint(); drag = {id: e.id, x: p.x, y: p.y, origin: {x: e.x, y: e.y}, moved: false}; }
    }
    render();
  };
  canvas.onpointermove = ev => {
    if (!project) return;
    const p = worldPoint(ev);
    $('#cursor').textContent = `X ${Math.round(p.x)}   Y ${Math.round(p.y)}`;
    if (!drag) return;
    if (drag.pan) { pan = {x: drag.origin.x + ev.clientX - drag.x, y: drag.origin.y + ev.clientY - drag.y}; draw(); }
    else if (drag.id) { const e = item(); if (e) { e.x = snapN(drag.origin.x + p.x - drag.x); e.y = snapN(drag.origin.y + p.y - drag.y); drag.moved = true; draw(); } }
  };
  function release(ev, cancel = false) {
    if (!drag) return;
    if (drag.ball && !cancel) {
      const e = level().elements.find(e => e.id === drag.ball), p = clampPoint(worldPoint(ev));
      testState.balls[e.id] ??= {x: e.x, y: e.y};
      testState.flight = {id: e.id, from: {...testState.balls[e.id]}, to: p, time: 0, arc: e.params?.arc ?? 100};
      testState.target = p; testState.pendingScript = 'ball'; testState.pendingElement = e;
      showTest('message', 'Łap piłkę!');
    } else if (drag.id) {
      if (cancel) { Object.assign(item(), drag.origin); history.pop(); }
      else if (drag.moved) changed('Zmieniono położenie.');
      else history.pop();
      render();
    }
    drag = null;
  }
  canvas.onpointerup = ev => release(ev);
  canvas.onpointercancel = ev => release(ev, true);
  canvas.onwheel = ev => { ev.preventDefault(); zoom = Math.max(.25, Math.min(6, zoom * (ev.deltaY < 0 ? 1.1 : 1 / 1.1))); draw(); };
  function clampPoint(p) { const w = level().walk; return {x: Math.max(w.x, Math.min(w.x + w.width, p.x)), y: Math.max(w.y, Math.min(w.y + w.height, p.y))}; }

  function showTest(kind, text, x, y) {
    const e = $('#testMessage');
    if (kind === 'thought') { e.hidden = true; testState.bubble = {kind, text, x: x ?? testState.dog.x, y: y ?? testState.dog.y - 220}; }
    else { e.textContent = text; e.hidden = false; testState.bubble = null; }
    testState.messageUntil = performance.now() + 3000;
  }

  const runtime = {
    none() {},
    message(e) { showTest('message', e.params?.text || e.name); },
    thought(e) {
      const fromDog = e.params?.from_dog !== false;
      showTest('thought', e.params?.text || '…', fromDog ? testState.dog.x : e.x, fromDog ? testState.dog.y - 220 : e.y - 60);
    },
    portal(e) {
      levelId = e.params?.target || levelId;
      testState = freshTest();
      if (e.params?.message) showTest('message', e.params.message);
      else showTest('message', level().name);
      fit(); render();
    },
    feed(e) { testState.target = clampPoint({x: e.x - 50, y: e.y}); testState.pendingScript = 'feed'; testState.pendingElement = e; },
    pet(e) { testState.target = clampPoint({x: e.x - 50, y: e.y}); testState.pendingScript = 'pet'; testState.pendingElement = e; },
    clean(e) { testState.target = clampPoint({x: e.x - 50, y: e.y}); testState.pendingScript = 'clean'; testState.pendingElement = e; },
    rest(e) { testState.target = clampPoint({x: e.x - 50, y: e.y}); testState.pendingScript = 'rest'; testState.pendingElement = e; },
    bark(e) { showTest('message', e.params?.message || 'Hau!'); },
    greet(e) { showTest('message', e.params?.text || 'Cześć, przyjacielu!'); },
    play_clip(e) { showTest('message', e.params?.message || (e.params?.clip || 'idle')); },
    walk_to(e) { testState.target = clampPoint({x: e.params?.x ?? e.x, y: e.params?.y ?? e.y}); if (e.params?.message) showTest('message', e.params.message); },
    ball() {}
  };
  function activate(e, p) {
    if (!e) { testState.target = clampPoint(p); return; }
    if (!isInteractive(e)) return;
    const run = runtime[e.script]; if (run) run(e);
  }

  function freshTest() { return {dog: {...level().spawn}, target: null, balls: {}, flight: null, pendingScript: null, pendingElement: null, bubble: null, messageUntil: 0}; }
  function stopTest() {
    testing = false; testState = null; drag = null;
    $('#test').textContent = '▶ Testuj'; $('#test').classList.remove('active');
    document.body.classList.remove('testing'); $('#testMessage').hidden = true;
    $('#hint').textContent = 'Wybierz grafikę z biblioteki, aby dodać ją do aktywnej warstwy.';
  }
  $('#test').onclick = () => {
    if (testing) { stopTest(); render(); return; }
    if (!valid()) return;
    testing = true; testState = freshTest();
    $('#test').textContent = '■ Zakończ test'; $('#test').classList.add('active');
    document.body.classList.add('testing');
    $('#hint').textContent = 'Kliknij ziemię lub element. Przeciągnij piłkę i puść. Portal przenosi do kolejnego poziomu.';
    render();
  };

  function completeScript() {
    const scriptId = testState.pendingScript, e = testState.pendingElement;
    testState.pendingScript = null; testState.pendingElement = null;
    if (!scriptId) return;
    const msgs = {feed: 'Gotowe · posiłek', pet: 'Gotowe · głaskanie', clean: 'Gotowe · czesanie', rest: 'Gotowe · odpoczynek', ball: 'Gotowe · aport'};
    const text = e?.params?.message || msgs[scriptId] || '';
    if (text) showTest('message', text);
  }

  function frame(now) {
    const dt = Math.min(.05, (now - lastTime) / 1000 || 0); lastTime = now;
    if (testing) {
      const s = testState, l = level();
      if (s.target) {
        const dx = s.target.x - s.dog.x, dy = s.target.y - s.dog.y, d = Math.hypot(dx, dy);
        const speed = s.pendingScript === 'ball' ? (l.runSpeed || 160) : (l.walkSpeed || 70);
        const step = speed * dt;
        if (d <= step) { s.dog.x = s.target.x; s.dog.y = s.target.y; s.target = null; if (s.flight === null || s.pendingScript !== 'ball') completeScript(); }
        else { s.dog.x += dx / d * step; s.dog.y += dy / d * step; }
      }
      if (s.flight) {
        const f = s.flight; f.time = Math.min(1, f.time + dt);
        s.balls[f.id] = {x: f.from.x + (f.to.x - f.from.x) * f.time, y: f.from.y + (f.to.y - f.from.y) * f.time - Math.sin(f.time * Math.PI) * (f.arc || 100)};
        if (f.time >= 1) s.flight = null;
      }
      if (now > s.messageUntil) { $('#testMessage').hidden = true; s.bubble = null; }
      draw();
    }
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);

  $('#undo').onclick = () => undo(); $('#redo').onclick = () => undo(true);
  $('#fit').onclick = fit;
  $('#zoomIn').onclick = () => { zoom = Math.min(6, zoom * 1.25); draw(); };
  $('#zoomOut').onclick = () => { zoom = Math.max(.25, zoom / 1.25); draw(); };
  $('#grid').onchange = draw;
  $('#deselect').onclick = () => { selected = null; render(); };
  $('#assetSearch').oninput = ev => { filter = ev.target.value.toLowerCase(); render(); };
  $('#projectName').onchange = ev => mutate(() => project.name = ev.target.value);

  $('#addLevel').onclick = async () => {
    const name = await ask('Nazwa nowego poziomu:', 'Nowy poziom');
    if (!name) return;
    mutate(() => { const l = newLevel(name); project.levels.push(l); levelId = l.id; selected = null; fit(); });
  };
  $('#duplicateLevel').onclick = () => mutate(() => {
    const l = clone(level()); const old = l.id; l.id = id('level'); l.name += ' · kopia';
    for (const e of l.elements) { e.id = id('item'); if (e.script === 'portal' && e.params?.target === old) e.params.target = l.id; }
    project.levels.push(l); levelId = l.id; selected = null;
  });
  $('#deleteLevel').onclick = async () => {
    if (project.levels.length <= 1) return;
    if (await confirmAction('Usunąć poziom „' + level().name + '”? Portale prowadzące do niego zostaną wyłączone.'))
      mutate(() => { removeLevel(project, levelId); levelId = project.startLevel; selected = null; });
  };
  $('#duplicateItem').onclick = () => {
    if (!item()) return;
    mutate(() => { const e = clone(item()); e.id = id('item'); e.name += ' · kopia'; e.x += 24; level().elements.push(e); selected = e.id; });
  };
  function deleteItem() { if (!item() || testing) return; mutate(() => { level().elements = level().elements.filter(e => e.id !== selected); selected = null; }); }
  $('#deleteItem').onclick = deleteItem;

  $('#save').onclick = () => {
    if (!valid()) return;
    const blob = new Blob([JSON.stringify(project, null, 2)], {type: 'application/json'}), url = URL.createObjectURL(blob), a = el('a');
    a.href = url; a.download = fileName; a.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000); saved();
    status('Przekazano JSON do pobrania. Sprawdź folder Pobrane.');
  };
  $('#saveRepo').onclick = async () => {
    if (!FS.hasRoot()) { inform('Najpierw wybierz folder YuFriend przyciskiem „Folder”.'); return; }
    if (!valid()) return;
    let name = await ask('Nazwa pliku w level-editor/projects (bez spacji):', fileName);
    if (!name) return;
    if (!name.endsWith('.json')) name += '.json';
    try {
      const existing = await FS.listProjects();
      if (existing.includes(name) && !await confirmAction('Nadpisać ' + name + '?')) return;
      await FS.writeProject(name, project);
      fileName = name; saved(); status('Zapisano projects/' + name);
    } catch (e) { status(e.message, true); inform(e.message); }
  };
  $('#open').onclick = async () => {
    const list = $('#projectList'); list.replaceChildren();
    if (FS.hasRoot()) {
      try {
        const files = await FS.listProjects();
        for (const name of files) {
          const b = el('button', '', name);
          b.onclick = async () => {
            if (dirty && !await confirmAction('Porzucić niezapisane zmiany?')) return;
            try { const p = await FS.readProject(name); await acceptProject(p); fileName = name === 'starter.json' ? 'moj-projekt.json' : name; $('#openDialog').close(); }
            catch (e) { inform(e.message); }
          };
          list.append(b);
        }
        if (!files.length) list.append(el('p', 'note', 'W folderze projects/ nie ma plików JSON.'));
      } catch (e) { list.append(el('p', 'note', 'Nie udało się odczytać projects/: ' + e.message)); }
    } else {
      list.append(el('p', 'note', 'Wybierz folder YuFriend, aby zobaczyć listę projektów.'));
    }
    $('#openDialog').showModal();
  };
  $('#openFile').onclick = () => $('#projectFile').click();
  $('#projectFile').onchange = async ev => {
    const f = ev.target.files[0]; if (!f) return;
    if (dirty && !await confirmAction('Porzucić niezapisane zmiany?')) return;
    try {
      if (f.size > 20 * 1024 * 1024) throw Error('Maksymalny rozmiar projektu: 20 MB.');
      await acceptProject(JSON.parse(await f.text())); fileName = f.name; $('#openDialog').close();
    } catch (e) { inform(e.message); }
    ev.target.value = '';
  };
  $('#newProject').onclick = async () => {
    if (!FS.hasRoot()) { inform('Wybierz folder YuFriend, aby wczytać starter.'); return; }
    if (dirty && !await confirmAction('Porzucić niezapisane zmiany?')) return;
    try {
      const p = await FS.readProject('starter.json');
      await acceptProject(p); fileName = 'moj-projekt.json';
      changed('Nowy projekt z Domem i Ogrodem.');
    } catch (e) { inform('Nie znaleziono startera: ' + e.message); }
  };
  $('#refreshAssets').onclick = async () => {
    await refreshDiskAssets();
    await loadImages();
    const extra = diskAssets.filter(d => !project.assets.some(a => a.id === d.id)).length;
    status(extra ? `Przeskanowano. ${extra} nowych grafik w folderze assets/.` : 'Przeskanowano. Brak nowych grafik.');
    render();
  };
  $('#importAsset').onclick = () => $('#assetFile').click();
  $('#assetFile').onchange = async ev => {
    for (const f of ev.target.files) {
      try {
        if (f.type !== 'image/png' || f.size > 2.8 * 1024 * 1024) throw Error('Wybierz PNG do 2,8 MB.');
        const data = await new Promise((resolve, reject) => { const reader = new FileReader(); reader.onload = () => resolve(reader.result); reader.onerror = reject; reader.readAsDataURL(f); });
        const img = new Image(); img.src = data; await img.decode();
        if (img.width > 4096 || img.height > 4096) throw Error('Maksymalny wymiar PNG: 4096 px.');
        if (project.assets.length >= 128) throw Error('Biblioteka może zawierać 128 grafik.');
        mutate(() => project.assets.push({id: id('asset'), name: f.name.replace(/\.png$/i, ''), source: data, width: img.width, height: img.height}), 'Zaimportowano ' + f.name);
        await loadImages();
      } catch (e) { inform(e.message); }
    }
    ev.target.value = '';
  };
  $('#runtimeHelp').onclick = () => {
    $('#command').textContent = `godot --path . --script res://scripts/levels/preview.gd -- --project=res://level-editor/projects/${fileName} --level=${levelId}`;
    $('#helpDialog').showModal();
  };

  $('#pickRoot').onclick = async () => {
    try {
      const name = await FS.pick();
      status(`Folder: ${name}`);
      $('#pickRootDialog').close();
      await initDogImage();
      // Show the project picker straight away so the user chooses which JSON
      // to load, instead of silently falling back to starter.json.
      $('#open').click();
    } catch (e) { status('Nie wybrano folderu: ' + e.message, true); }
  };
  $('#changeRoot').onclick = () => $('#pickRoot').click();
  $('#forgetRoot').onclick = async () => {
    if (!await confirmAction('Zapomnieć o folderze? Edytor zapyta ponownie przy następnym uruchomieniu.')) return;
    await FS.forget(); status('Folder zapomniany.'); render();
  };

  for (const b of document.querySelectorAll('[data-close]')) b.onclick = () => b.closest('dialog').close();
  addEventListener('keydown', ev => {
    if (ev.target.closest('input,textarea,select') || document.querySelector('dialog[open]')) return;
    if ((ev.ctrlKey || ev.metaKey) && ev.key.toLowerCase() === 'z') { ev.preventDefault(); undo(ev.shiftKey); }
    else if ((ev.ctrlKey || ev.metaKey) && ev.key.toLowerCase() === 's') { ev.preventDefault(); $('#save').click(); }
    else if (ev.key === 'Delete' || ev.key === 'Backspace') { ev.preventDefault(); deleteItem(); }
    else if (ev.key === 'Escape') { stopTest(); selected = null; render(); }
  });
  addEventListener('beforeunload', ev => { if (dirty) { ev.preventDefault(); ev.returnValue = ''; } });
  new ResizeObserver(draw).observe(stage);

  async function bootProject() {
    await initDogImage();
    try {
      let p = await FS.readProject('starter.json');
      const draft = localStorage.getItem('yufriend-editor-draft');
      if (draft && await confirmAction('Przywrócić niezapisaną kopię projektu z przeglądarki?')) {
        p = JSON.parse(draft); await acceptProject(p); changed('Przywrócono kopię roboczą.');
      } else {
        await acceptProject(p);
      }
    } catch (e) { status('Nie udało się otworzyć projektu: ' + e.message, true); }
  }

  async function boot() {
    const name = await FS.restore();
    if (name) { status(`Folder: ${name}`); await bootProject(); render(); return; }
    if (!FS.supported) {
      $('#pickRoot').disabled = true;
      $('#pickRootText').textContent = 'Ta przeglądarka nie obsługuje File System Access API. Użyj „Wybierz plik JSON" w dialogu „Otwórz".';
    } else {
      status('Wybierz folder YuFriend, aby rozpocząć.');
    }
    $('#pickRootDialog').showModal();
  }
  boot();
})();
