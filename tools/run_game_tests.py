#!/usr/bin/env python3
"""Run isolated Godot suites; runtime errors fail even when Godot exits zero."""
import argparse, os, pathlib, subprocess, tempfile, sys
p=argparse.ArgumentParser();p.add_argument('--ui',action='store_true');args=p.parse_args()
root=pathlib.Path(__file__).resolve().parents[1]
godot=os.environ.get('GODOT_BIN','/Applications/Godot.app/Contents/MacOS/Godot')
failed=[]
with tempfile.TemporaryDirectory(prefix='yufriend-tests-') as temp:
 env=dict(os.environ,YUFRIEND_TEST_ROOT=temp)
 suites=sorted((root/'tests').glob('ui_*.gd' if args.ui else 'test_*.gd'))
 for suite in suites:
  cmd=[godot,'--path',str(root),'--log-file',str(pathlib.Path(temp)/'engine.log'),'--script','res://tests/'+suite.name]
  if args.ui:cmd[1:1]=['--always-on-top','--disable-vsync','--max-fps','60']
  else:cmd.insert(1,'--headless')
  try:
   result=subprocess.run(cmd,env=env,capture_output=True,text=True,timeout=120)
   output=result.stdout+result.stderr
   bad=result.returncode!=0 or 'SCRIPT ERROR:' in output or 'Parse Error:' in output
   if bad:print(output)
  except subprocess.TimeoutExpired:bad=True;print('TIMEOUT',suite.name)
  print(('FAIL' if bad else 'PASS'),suite.name,flush=True)
  if bad:failed.append(suite.name)
print(f'{len(suites)-len(failed)}/{len(suites)} suites passed')
sys.exit(bool(failed))
