"use strict";
(() => {
  const R = globalThis.YF_REGISTRY;
  const LAYERS = ['background', 'middle', 'foreground'];
  const SCRIPTS = Object.fromEntries(R.scripts.map(s => [s.id, s]));
  const SCRIPT_LIST = R.scripts;
  const CLIPS = R.clips || [];
  const SCRIPT_OPTIONS = Object.fromEntries(R.scripts.map(s => [s.id, (s.icon ? s.icon + ' ' : '') + s.label]));
  const DEFAULT_WALK_SPEED = 70, DEFAULT_RUN_SPEED = 160;

  const clone = value => structuredClone(value);
  const id = prefix => `${prefix}-${crypto.randomUUID().slice(0, 8)}`;

  function newLevel(name = 'Nowy poziom') {
    return {id: id('level'), name, width: 1440, height: 540, spawn: {x: 670, y: 502}, walk: {x: 95, y: 466, width: 1250, height: 42}, walkSpeed: DEFAULT_WALK_SPEED, runSpeed: DEFAULT_RUN_SPEED, elements: []};
  }

  function defaultParams(scriptId, project) {
    const schema = SCRIPTS[scriptId]?.params || {};
    const out = {};
    for (const [key, def] of Object.entries(schema)) {
      if (def.default !== undefined) out[key] = def.default;
      else if (def.type === 'number') out[key] = 0;
      else if (def.type === 'bool') out[key] = false;
      else if (def.type === 'level') out[key] = project?.levels?.[0]?.id || '';
      else out[key] = '';
    }
    return out;
  }

  function newElement(asset, layer = 'middle', level = null) {
    const isBackground = /(?:^|[-/])background(?:-hd)?\.png$/i.test(asset.source || '') || /background/i.test(asset.name || '');
    const authored = asset.defaultSize;
    let width, height;
    if (isBackground) {
      width = level?.width || 1440; height = level?.height || 540;
    } else if (authored?.width > 0 && authored?.height > 0) {
      width = authored.width; height = authored.height;
    } else if (Math.max(asset.width, asset.height) > 128) {
      const scale = Math.min(300 / asset.width, 220 / asset.height);
      width = Math.max(1, Math.round(asset.width * scale));
      height = Math.max(1, Math.round(asset.height * scale));
    } else {
      width = asset.width * 3; height = asset.height * 3;
    }
    return {
      id: id('item'), name: asset.name, asset: asset.id, layer,
      x: isBackground ? 0 : 720, y: isBackground ? 0 : 315, width, height,
      pivot: isBackground ? {x: 0, y: 0} : {x: asset.width / 2, y: asset.height},
      visible: true, locked: false, static: true,
      script: 'none', params: {}
    };
  }

  const isInteractive = e => e.script !== 'none';

  function isAnimationAsset(asset) {
    const source = String(asset?.source || '').toLowerCase();
    const label = `${asset?.id || ''} ${asset?.name || ''}`.toLowerCase();
    return source.startsWith('res://level-editor/assets/sprites-')
      || source.startsWith('res://level-editor/assets/sprites/')
      || source.startsWith('res://assets/sprites/')
      || /(?:^|\/)(?:frames|sheets)(?:\/|$)/.test(source)
      || /(?:^|\/)[^/]*spritesheet[^/]*(?:\/|$)/.test(source)
      || /sprite[\s_-]*sheet|arkusz animacji/.test(label);
  }

  function setScript(e, scriptId, project) {
    e.script = scriptId;
    e.params = defaultParams(scriptId, project);
    const forced = SCRIPTS[scriptId]?.static;
    if (typeof forced === 'boolean') e.static = forced;
  }

  function ordered(level) {
    return level.elements.map((e, i) => ({...e, _order: i}))
      .sort((a, b) => LAYERS.indexOf(a.layer) - LAYERS.indexOf(b.layer) || (a.layer === 'middle' ? a.y - b.y : 0) || a._order - b._order);
  }

  function rect(e, asset) {
    return {x: e.x - e.pivot.x * e.width / asset.width, y: e.y - e.pivot.y * e.height / asset.height, width: e.width, height: e.height};
  }

  function removeLevel(project, levelId) {
    if (project.levels.length <= 1) throw Error('Projekt musi zawierać przynajmniej jeden poziom.');
    project.levels = project.levels.filter(l => l.id !== levelId);
    if (project.startLevel === levelId) project.startLevel = project.levels[0].id;
    for (const l of project.levels) for (const e of l.elements) {
      if (e.script === 'portal' && e.params?.target === levelId) { e.script = 'none'; e.params = {}; }
    }
  }

  function migrateElement(e) {
    if (e.script !== undefined && e.params !== undefined && e.behavior === undefined) return e;
    const legacy = e.behavior || 'none';
    const interactive = e.interactive === true;
    let script = 'none', params = {};
    if (!interactive || legacy === 'none') script = 'none';
    else if (legacy === 'script') {
      script = e.script === 'bark' ? 'bark' : 'greet';
      if (script === 'greet') params = {text: e.text || 'Cześć, przyjacielu!'};
      else params = {message: e.text || 'Hau!', clip: 'bark_stand'};
    }
    else if (legacy === 'portal') { script = 'portal'; params = {target: e.target || '', message: e.text || ''}; }
    else if (legacy === 'message') { script = 'message'; params = {text: e.text || e.name || '', duration: 4}; }
    else if (SCRIPTS[legacy]) { script = legacy; params = defaultParams(legacy); if (e.text) params.message = e.text; }
    const {behavior, target, script: oldScript, text, interactive: _i, ...rest} = e;
    return {...rest, script, params};
  }

  function migrateLevel(l) {
    const out = {...l};
    if (out.walkSpeed === undefined) out.walkSpeed = DEFAULT_WALK_SPEED;
    if (out.runSpeed === undefined) out.runSpeed = DEFAULT_RUN_SPEED;
    out.elements = (l.elements || []).map(migrateElement);
    return out;
  }

  function migrate(project) {
    if (!project || typeof project !== 'object') return project;
    const out = {...project};
    out.levels = (project.levels || []).map(migrateLevel);
    return out;
  }

  function paramCheck(schema, value, project) {
    if (schema.type === 'number') return typeof value === 'number' && Number.isFinite(value) && (schema.min === undefined || value >= schema.min) && (schema.max === undefined || value <= schema.max);
    if (schema.type === 'bool') return typeof value === 'boolean';
    if (schema.type === 'level') return project.levels.some(l => l.id === value);
    if (schema.type === 'clip') return typeof value === 'string' && value.length > 0 && value.length <= 64;
    if (schema.type === 'string') return typeof value === 'string' && value.length <= (schema.max || 200);
    if (schema.type === 'text') return typeof value === 'string' && value.length <= (schema.max || 500);
    return true;
  }

  function validate(p) {
    const errors = [];
    const fail = (ok, msg) => { if (!ok) errors.push(msg); return ok; };
    const finite = (n, min, max) => typeof n === 'number' && Number.isFinite(n) && n >= min && n <= max;
    const str = (v, max = 100) => typeof v === 'string' && v.length <= max;
    const ident = v => str(v, 64) && /^[a-zA-Z][a-zA-Z0-9_-]*$/.test(v);
    if (!p || typeof p !== 'object') return ['To nie jest projekt.'];
    fail(p.format === 'yufriend-levels' && p.version === 1, 'Nieobsługiwana wersja projektu.');
    fail(str(p.name) && p.name.trim().length > 0, 'Podaj nazwę projektu.');
    if (!fail(Array.isArray(p.assets) && p.assets.length <= 128, 'Nieprawidłowa biblioteka grafik (maks. 128).')
      || !fail(Array.isArray(p.levels) && p.levels.length > 0 && p.levels.length <= 64, 'Projekt wymaga 1–64 poziomów.')) return errors;
    const assets = new Map(), levels = new Set();
    for (const a of p.assets) {
      if (!a || typeof a !== 'object') { errors.push('Nieprawidłowa grafika.'); continue; }
      fail(ident(a.id) && !assets.has(a.id), 'Nieprawidłowe lub powtórzone ID grafiki.'); assets.set(a.id, a);
      fail(str(a.name), 'Nieprawidłowa nazwa grafiki.');
      fail(finite(a.width, 1, 4096) && finite(a.height, 1, 4096), 'Grafika: rozmiar 1–4096 px.');
      fail(str(a.source, 4000000) && ((/^res:\/\/(assets|level-editor\/assets)\/[a-zA-Z0-9_./-]+\.png$/.test(a.source) && !a.source.includes('..')) || /^data:image\/png;base64,[A-Za-z0-9+/=]+$/.test(a.source)), 'Grafika musi być PNG w repozytorium lub osadzonym PNG.');
    }
    for (const l of p.levels) {
      if (!l || typeof l !== 'object') { errors.push('Nieprawidłowy poziom.'); continue; }
      fail(ident(l.id) && !levels.has(l.id), 'Nieprawidłowe lub powtórzone ID poziomu.'); levels.add(l.id);
    }
    fail(levels.has(p.startLevel), 'Nie znaleziono poziomu startowego.');
    for (const l of p.levels) {
      if (!l || typeof l !== 'object') continue;
      fail(str(l.name) && l.name.trim().length > 0, 'Poziom musi mieć nazwę.');
      fail(finite(l.width, 240, 8192) && finite(l.height, 120, 4096), 'Poziom: szerokość 240–8192, wysokość 120–4096.');
      fail(finite(l.walkSpeed, 1, 2000), `${l.name}: prędkość chodu 1–2000.`);
      fail(finite(l.runSpeed, 1, 4000), `${l.name}: prędkość biegu 1–4000.`);
      const w = l.walk, s = l.spawn;
      const walkOK = w && finite(w.x, 0, l.width) && finite(w.y, 0, l.height) && finite(w.width, 1, l.width) && finite(w.height, 1, l.height) && w.x + w.width <= l.width && w.y + w.height <= l.height;
      fail(walkOK, `${l.name}: pas ruchu musi mieścić się w poziomie.`);
      fail(walkOK && s && finite(s.x, w.x, w.x + w.width) && finite(s.y, w.y, w.y + w.height), `${l.name}: start psa musi być w pasie ruchu.`);
      if (!fail(Array.isArray(l.elements) && l.elements.length <= 500, 'Maksymalnie 500 elementów na poziom.')) continue;
      const ids = new Set();
      for (const e of l.elements) {
        if (!e || typeof e !== 'object') { errors.push('Nieprawidłowy element.'); continue; }
        fail(ident(e.id) && !ids.has(e.id), 'Nieprawidłowe lub powtórzone ID elementu.'); ids.add(e.id);
        fail(str(e.name) && assets.has(e.asset) && LAYERS.includes(e.layer), 'Element: brak nazwy, grafiki lub warstwy.');
        fail(finite(e.x, -8192, 16384) && finite(e.y, -8192, 16384) && finite(e.width, 1, 16384) && finite(e.height, 1, 16384), 'Nieprawidłowa pozycja lub rozmiar elementu.');
        const a = assets.get(e.asset);
        fail(a && e.pivot && finite(e.pivot.x, 0, a.width) && finite(e.pivot.y, 0, a.height), 'Punkt podstawy musi leżeć na płótnie grafiki.');
        fail(['visible', 'locked', 'static'].every(k => typeof e[k] === 'boolean'), 'Nieprawidłowe właściwości elementu.');
        if (!fail(Object.hasOwn(SCRIPTS, e.script), `Nieznany skrypt: ${e.script}`)) continue;
        const def = SCRIPTS[e.script];
        if (typeof def.static === 'boolean') fail(e.static === def.static, `Skrypt ${e.script} wymaga static=${def.static}.`);
        fail(e.params && typeof e.params === 'object', 'Element bez parametrów.');
        const schema = def.params || {};
        for (const [key, pdef] of Object.entries(schema)) {
          fail(paramCheck(pdef, e.params?.[key], p), `${e.name}: parametr ${key} (${pdef.type}) jest nieprawidłowy.`);
        }
      }
    }
    return errors;
  }

  globalThis.YF = {
    LAYERS, SCRIPTS, SCRIPT_LIST, SCRIPT_OPTIONS, CLIPS,
    DEFAULT_WALK_SPEED, DEFAULT_RUN_SPEED,
    clone, id, newLevel, newElement, defaultParams, setScript, isInteractive, isAnimationAsset,
    ordered, rect, removeLevel,
    migrate, migrateElement, migrateLevel, validate
  };
})();
