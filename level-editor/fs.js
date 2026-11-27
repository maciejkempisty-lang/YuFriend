"use strict";
// File System Access API wrapper. The editor speaks only to a single root
// directory the user picks once (the YuFriend repo root). Handle survives
// reloads via IndexedDB; permissions are re-requested on demand.
(() => {
  const DB_NAME = 'yufriend-editor', STORE = 'handles', KEY = 'root';
  const MAGIC = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
  const ID_RE = /^[a-zA-Z][a-zA-Z0-9_-]*$/;
  const GAME_DIRS = ['art/yard/sprites', 'art/home/sprites', 'art/environments', 'sprites/puppy/pixel'];

  const supported = typeof self !== 'undefined' && 'showDirectoryPicker' in self;
  let root = null;
  const blobUrls = new Map();   // repo-relative path -> blob URL
  const assetHandles = new Map(); // repo-relative path -> FileSystemFileHandle

  function openDb() {
    return new Promise((ok, err) => {
      const req = indexedDB.open(DB_NAME, 1);
      req.onupgradeneeded = () => req.result.createObjectStore(STORE);
      req.onsuccess = () => ok(req.result);
      req.onerror = () => err(req.error);
    });
  }
  async function getStored() {
    try {
      const db = await openDb();
      return await new Promise((ok, err) => {
        const tx = db.transaction(STORE, 'readonly');
        const req = tx.objectStore(STORE).get(KEY);
        req.onsuccess = () => ok(req.result || null);
        req.onerror = () => err(req.error);
      });
    } catch { return null; }
  }
  async function putStored(handle) {
    try {
      const db = await openDb();
      await new Promise((ok, err) => {
        const tx = db.transaction(STORE, 'readwrite');
        tx.objectStore(STORE).put(handle, KEY);
        tx.oncomplete = () => ok();
        tx.onerror = () => err(tx.error);
      });
    } catch {}
  }
  async function ensureAccess(handle) {
    if (typeof handle.queryPermission !== 'function') return true;
    if (await handle.queryPermission({mode: 'readwrite'}) === 'granted') return true;
    return await handle.requestPermission({mode: 'readwrite'}) === 'granted';
  }
  async function verifyRoot(handle) {
    const le = await handle.getDirectoryHandle('level-editor');
    await le.getFileHandle('scripts.json');
  }
  function resetCaches() {
    for (const url of blobUrls.values()) URL.revokeObjectURL(url);
    blobUrls.clear(); assetHandles.clear();
  }

  async function dir(path, create = false) {
    let d = root;
    for (const p of path.split('/').filter(Boolean)) d = await d.getDirectoryHandle(p, {create});
    return d;
  }
  async function file(path, create = false) {
    const parts = path.split('/').filter(Boolean);
    const name = parts.pop();
    const d = parts.length ? await dir(parts.join('/'), create) : root;
    return d.getFileHandle(name, {create});
  }

  async function pick() {
    if (!supported) throw Error('Ta przeglądarka nie obsługuje wyboru folderu. Użyj Chrome lub Edge.');
    const handle = await self.showDirectoryPicker({id: 'yufriend-root', mode: 'readwrite'});
    await verifyRoot(handle);
    await putStored(handle);
    root = handle; resetCaches();
    return handle.name;
  }
  async function restore() {
    if (!supported) return null;
    const stored = await getStored();
    if (!stored) return null;
    if (!await ensureAccess(stored)) return null;
    try { await verifyRoot(stored); } catch { return null; }
    root = stored; resetCaches();
    return stored.name;
  }
  async function forget() {
    try {
      const db = await openDb();
      await new Promise(ok => {
        const tx = db.transaction(STORE, 'readwrite');
        tx.objectStore(STORE).delete(KEY);
        tx.oncomplete = ok; tx.onerror = ok;
      });
    } catch {}
    root = null; resetCaches();
  }

  const hasRoot = () => !!root;
  const rootName = () => root?.name || '';

  function resPath(src) {
    if (typeof src !== 'string' || !src.startsWith('res://')) return null;
    return src.slice(6);
  }

  async function resolveSource(src) {
    if (!src) return null;
    if (src.startsWith('data:') || src.startsWith('blob:') || src.startsWith('http')) return src;
    const path = resPath(src);
    if (!path || !root) return null;
    if (blobUrls.has(path)) return blobUrls.get(path);
    try {
      const h = assetHandles.get(path) || await file(path);
      const url = URL.createObjectURL(await h.getFile());
      blobUrls.set(path, url);
      return url;
    } catch { return null; }
  }

  function idFor(rel) {
    const base = rel.replace(/\.png$/i, '').replace(/\//g, '-').replace(/\s+/g, '_');
    const clean = base.replace(/[^a-zA-Z0-9_-]/g, '');
    if (!ID_RE.test(clean) || clean.length > 64) return null;
    return clean;
  }
  function pretty(rel) {
    const base = rel.replace(/\.png$/i, '').split('/').pop();
    return base.replace(/[_-]/g, ' ').trim() || 'grafika';
  }
  async function readPng(handle) {
    const blob = await handle.getFile();
    if (blob.size < 24) return null;
    const head = new Uint8Array(await blob.slice(0, 24).arrayBuffer());
    for (let i = 0; i < 8; i++) if (head[i] !== MAGIC[i]) return null;
    const dv = new DataView(head.buffer);
    const w = dv.getUint32(16), h = dv.getUint32(20);
    if (w < 1 || w > 4096 || h < 1 || h > 4096) return null;
    return {w, h};
  }
  async function walk(dirHandle, base, onPng) {
    for await (const [name, h] of dirHandle.entries()) {
      if (name.startsWith('.')) continue;
      if (h.kind === 'directory') await walk(h, `${base}${name}/`, onPng);
      else if (h.kind === 'file' && name.toLowerCase().endsWith('.png')) await onPng(`${base}${name}`, h);
    }
  }

  async function scanAssets() {
    if (!root) return [];
    const result = [], seen = new Set();
    const add = async (dirPath, srcPrefix) => {
      let dh;
      try { dh = await dir(dirPath); } catch { return; }
      await walk(dh, '', async (rel, handle) => {
        const png = await readPng(handle);
        if (!png) return;
        const aid = idFor(rel);
        if (!aid || seen.has(aid)) return;
        seen.add(aid);
        const path = `${dirPath}/${rel}`;
        assetHandles.set(path, handle);
        result.push({id: aid, name: pretty(rel), source: `${srcPrefix}${rel}`, width: png.w, height: png.h});
      });
    };
    await add('level-editor/assets', 'res://level-editor/assets/');
    for (const d of GAME_DIRS) await add(`assets/${d}`, `res://assets/${d}/`);
    result.sort((a, b) => a.id.localeCompare(b.id));
    return result;
  }

  async function listProjects() {
    if (!root) return [];
    const names = [];
    try {
      const d = await dir('level-editor/projects');
      for await (const [name, h] of d.entries()) {
        if (h.kind === 'file' && /^[a-zA-Z0-9_-]+\.json$/.test(name)) names.push(name);
      }
    } catch {}
    return names.sort();
  }
  async function readProject(name) {
    const h = await file(`level-editor/projects/${name}`);
    const text = await (await h.getFile()).text();
    return JSON.parse(text);
  }
  async function writeProject(name, data) {
    if (name === 'starter.json') throw Error('Zapisz pod nową nazwą — starter jest wzorcem.');
    if (!/^[a-zA-Z0-9_-]{1,80}\.json$/.test(name)) throw Error('Użyj liter, cyfr, myślnika i podkreślenia (do 80 znaków).');
    const d = await dir('level-editor/projects', true);
    const fh = await d.getFileHandle(name, {create: true});
    const w = await fh.createWritable();
    try {
      await w.write(JSON.stringify(data, null, 2) + '\n');
      await w.close();
    } catch (e) {
      try { await w.abort(); } catch {}
      throw e;
    }
  }

  globalThis.YF_FS = {
    supported, pick, restore, forget, hasRoot, rootName,
    resolveSource, scanAssets, listProjects, readProject, writeProject
  };
})();
