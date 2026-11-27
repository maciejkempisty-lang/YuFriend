import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const root = new URL('../', import.meta.url);
const ctx = {console, crypto, structuredClone, globalThis: undefined};
vm.createContext(ctx);
ctx.globalThis = ctx;
for (const name of ['registry.js', 'model.js']) {
  vm.runInContext(fs.readFileSync(new URL(name, root), 'utf8'), ctx);
}
const {
  clone, validate, ordered, rect, newLevel, newElement, removeLevel, migrate, setScript, SCRIPTS, isAnimationAsset
} = ctx.YF;
// vm context has its own Object prototype; normalize before strict-deep comparison.
const norm = v => JSON.parse(JSON.stringify(v));
const eq = (a, b) => assert.deepEqual(norm(a), norm(b));
const starter = JSON.parse(fs.readFileSync(new URL('projects/starter.json', root)));
const scriptsJson = JSON.parse(fs.readFileSync(new URL('scripts.json', root)));

test('registry.js matches scripts.json (shared contract)', () => {
  eq(ctx.YF_REGISTRY, scriptsJson);
});

test('starter and JSON round trip use the shared v1 contract', () =>
  eq(validate(JSON.parse(JSON.stringify(starter))), []));

test('new level and imported element remain valid', () => {
  const p = clone(starter), l = newLevel('Las');
  p.levels.push(l);
  l.elements.push(newElement(p.assets[0], 'foreground'));
  eq(validate(p), []);
});

test('HD art enters the scene at a practical size', () => {
  const l = newLevel('Pokój');
  const ball = newElement({id: 'hd-ball', name: 'Piłka HD', source: 'res://level-editor/assets/warm-v1-yard-ball-hd.png', width: 1261, height: 1247,
    defaultSize: {width: 71, height: 70}}, 'middle', l);
  assert.equal(ball.width, 71);
  assert.equal(ball.height, 70);
  const custom = newElement({id: 'hd-custom', name: 'Dekoracja', source: 'res://level-editor/assets/custom.png', width: 2048, height: 1024}, 'middle', l);
  assert.ok(custom.width <= 300 && custom.height <= 220);
  const background = newElement({id: 'hd-background', name: 'Tło', source: 'res://level-editor/assets/warm-v1-home-background-hd.png', width: 2172, height: 724}, 'background', l);
  assert.equal(background.width, l.width);
  assert.equal(background.height, l.height);
  eq(background.pivot, {x: 0, y: 0});
});

test('animation sheets are excluded from the editor library', () => {
  assert.equal(isAnimationAsset({source: 'res://level-editor/assets/sprites-Golden-spritesheet-run_right-spritesheet.png'}), true);
  assert.equal(isAnimationAsset({source: 'res://assets/sprites/puppy/pixel/sheets/walk.png'}), true);
  assert.equal(isAnimationAsset({source: 'data:image/png;base64,abc', name: 'spritesheet'}), true);
  assert.equal(isAnimationAsset({source: 'res://level-editor/assets/yard-garden.png'}), false);
});

test('deleting a level repairs portals and starting level', () => {
  const p = clone(starter);
  removeLevel(p, 'yard');
  assert.equal(p.levels.length, 1);
  assert.equal(p.levels[0].elements.find(e => e.id === 'door').script, 'none');
  eq(validate(p), []);
  assert.throws(() => removeLevel(p, 'home'));
});

test('middle sorts by base and layers stay independent', () => {
  const l = {elements: [
    {id: 'a', layer: 'middle', y: 300},
    {id: 'b', layer: 'foreground', y: 0},
    {id: 'c', layer: 'middle', y: 200},
    {id: 'd', layer: 'background', y: 999}
  ]};
  eq(ordered(l).map(e => e.id), ['d', 'c', 'a', 'b']);
});

test('asset pixel pivot transforms without shifting the world image', () => {
  eq(
    rect({x: 485, y: 325, width: 60, height: 36, pivot: {x: 10, y: 10}}, {width: 20, height: 12}),
    {x: 455, y: 295, width: 60, height: 36}
  );
});

test('script registry exposes message, thought and portal', () => {
  for (const id of ['none', 'message', 'thought', 'portal', 'feed', 'pet', 'clean', 'rest', 'ball', 'bark', 'greet', 'play_clip', 'walk_to', 'bath', 'cuddle', 'drink', 'sniff', 'course', 'timed_course', 'water', 'hide', 'visitor']) {
    assert.ok(SCRIPTS[id], 'missing script: ' + id);
  }
  assert.equal(SCRIPTS.ball.static, false);
});

test('setScript resets params and syncs forced static', () => {
  const p = clone(starter), e = newElement(p.assets[0], 'middle');
  setScript(e, 'ball', p);
  assert.equal(e.static, false);
  assert.equal(e.params.arc, 100);
  setScript(e, 'message', p);
  assert.equal(e.params.text, 'Cześć!');
  assert.equal(e.params.duration, 4);
});

test('migrate upgrades legacy behavior/text/target to script+params', () => {
  const legacy = {
    format: 'yufriend-levels', version: 1, name: 'legacy', startLevel: 'home',
    assets: starter.assets, levels: [{...clone(starter.levels[0]), elements: [
      {id: 'bed', name: 'Legowisko', asset: 'bed', layer: 'background', x: 205, y: 322,
       width: 180, height: 72, pivot: {x: 30, y: 18}, visible: true, locked: false, static: true,
       interactive: true, behavior: 'rest', target: '', script: '', text: ''},
      {id: 'door', name: 'Drzwi', asset: 'door', layer: 'background', x: 1300, y: 260,
       width: 126, height: 192, pivot: {x: 21, y: 63}, visible: true, locked: false, static: true,
       interactive: true, behavior: 'portal', target: 'home', script: '', text: 'Chodź!'}
    ]}, clone(starter.levels[1])]
  };
  const upgraded = migrate(legacy);
  assert.equal(upgraded.levels[0].elements[0].script, 'rest');
  assert.equal(upgraded.levels[0].elements[1].script, 'portal');
  assert.equal(upgraded.levels[0].elements[1].params.target, 'home');
  assert.equal(upgraded.levels[0].elements[1].params.message, 'Chodź!');
  assert.equal(upgraded.levels[0].walkSpeed, 70);
});

for (const [label, change] of Object.entries({
  version: p => p.version = 99,
  duplicate: p => p.levels.push(clone(p.levels[0])),
  portal: p => p.levels[0].elements.find(e => e.id === 'door').params.target = 'missing',
  geometry: p => p.levels[0].spawn.x = -1,
  unknownScript: p => p.levels[0].elements[0].script = 'eval',
  path: p => p.assets[0].source = 'res://assets/../private.png',
  staticBall: p => p.levels[0].elements.find(e => e.id === 'ball').static = true,
  finite: p => p.levels[0].elements[0].x = NaN,
  nullElement: p => p.levels[0].elements.push(null),
  badParam: p => p.levels[0].elements.find(e => e.id === 'food').params.fullness = 999,
  slowDog: p => p.levels[0].walkSpeed = 0,
})) {
  test('rejects ' + label, () => {
    const p = clone(starter);
    change(p);
    assert.ok(validate(p).length, 'expected error for ' + label);
  });
}
