"""Rebuild starter metadata from the existing game art exports."""
import json, struct
from pathlib import Path
ROOT = Path(__file__).resolve().parent
REGISTRY = json.loads((ROOT / 'scripts.json').read_text())
SCRIPTS = {s['id']: s for s in REGISTRY['scripts']}

def defaults(script_id):
    out = {}
    for k, pdef in SCRIPTS.get(script_id, {}).get('params', {}).items():
        if 'default' in pdef: out[k] = pdef['default']
        elif pdef.get('type') == 'number': out[k] = 0
        elif pdef.get('type') == 'bool': out[k] = False
        else: out[k] = ''
    return out

assets = []
def asset(key, name, path):
    data = (ROOT.parent / path).read_bytes()
    w, h = struct.unpack('>II', data[16:24])
    assets.append(dict(id=key, name=name, source='res://' + path, width=w, height=h))
    return assets[-1]

def element(key, name, a, layer, x, y, script='none', pivot=None, static=True, params=None):
    forced = SCRIPTS.get(script, {}).get('static')
    if isinstance(forced, bool): static = forced
    merged = defaults(script)
    if params: merged.update(params)
    return dict(id=key, name=name, asset=a['id'], layer=layer, x=x, y=y,
                width=a['width'] * 3, height=a['height'] * 3,
                pivot=pivot or dict(x=a['width'] / 2, y=a['height']),
                visible=True, locked=False, static=static,
                script=script, params=merged)

home = dict(id='home', name='Dom', width=1440, height=360,
            spawn=dict(x=670, y=322), walk=dict(x=95, y=286, width=1250, height=42),
            walkSpeed=70, runSpeed=160, elements=[])
yard = dict(id='yard', name='Ogród', width=1440, height=360,
            spawn=dict(x=670, y=322), walk=dict(x=95, y=286, width=1250, height=42),
            walkSpeed=70, runSpeed=160, elements=[])
for level in [home, yard]:
    a = asset(level['id'] + '-background', level['name'] + ' — tło', 'level-editor/assets/' + level['id'] + '-background.png')
    level['elements'].append(element('background', 'Tło', a, 'background', 0, 0, pivot=dict(x=0, y=0)))

for key, name, x, y, pivot, script, params in [
    ('bed', 'Legowisko', 205, 322, (30, 18), 'rest', None),
    ('food', 'Miska', 485, 325, (10, 10), 'feed', None),
    ('toys', 'Kosz', 1090, 316, (17, 25), 'message', {'text': 'W koszu czekają zabawki.'}),
    ('door', 'Drzwi do ogrodu', 1300, 260, (21, 63), 'portal', {'target': 'yard', 'message': 'Idziemy do ogrodu!'}),
    ('ball', 'Piłka', 890, 317, (6, 6), 'ball', None),
]:
    a = asset(key, name, 'level-editor/assets/' + key + '.png')
    e = element(key, name, a, 'background' if key in ['bed', 'door'] else 'middle',
                x, y, script, dict(x=pivot[0], y=pivot[1]), key != 'ball', params)
    home['elements'].append(e)
    if key == 'ball':
        yard['elements'].append(dict(e))

# Crops mirror YardSpriteLayout; anchors preserve the exact world positions.
locations = {'gate': (93, 183, 150, 276), 'garden': (477, 264, 550, 300), 'dig': (600, 285, 600, 285),
             'fetch': (813, 258, 850, 312), 'bush_0': (270, 204, 350, 294), 'bush_1': (669, 204, 750, 294),
             'bush_2': (1068, 204, 1150, 294), 'outing': (1269, 246, 1296, 300),
             'shade': (144, 186, 144, 186), 'course': (975, 231, 1005, 294),
             'puddle': (351, 294, 351, 294), 'sprinkler': (1281, 279, 1305,312)}
names = ['Furtka', 'Ogródek', 'Piaskownica', 'Aport', 'Krzak 1', 'Krzak 2', 'Krzak 3',
         'Tabliczka', 'Miejsce odpoczynku', 'Tor', 'Kałuża', 'Zraszacz']
for (key, (cx, cy, x, y)), name in zip(locations.items(), names):
    a = asset('yard-' + key, name, 'level-editor/assets/yard-' + key + '.png')
    script = 'portal' if key == 'gate' else 'none'
    params = {'target': 'home', 'message': 'Wracamy do domu.'} if key == 'gate' else None
    layer = 'background' if key in ['dig', 'shade', 'puddle'] else 'middle'
    e = element(key, name, a, layer, x, y, script, dict(x=(x - cx) / 3, y=(y - cy) / 3), True, params)
    yard['elements'].append(e)

project = dict(format='yufriend-levels', version=1, name='YuFriend · Dom i ogród',
               startLevel='home', assets=assets, levels=[home, yard])
(ROOT / 'projects/_backup').mkdir(exist_ok=True)
(ROOT / 'projects/_backup/starter.json').write_text(json.dumps(project, ensure_ascii=False, indent=2) + '\n')
print('Wrote', ROOT / 'projects/_backup/starter.json')
