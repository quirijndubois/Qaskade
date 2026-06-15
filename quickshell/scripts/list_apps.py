import os, glob, sys

result = []
dirs = (glob.glob('/usr/share/applications/*.desktop')
      + glob.glob(os.path.expanduser('~/.local/share/applications/*.desktop')))

for path in dirs:
    d = {}
    try:
        with open(path, encoding='utf-8', errors='ignore') as f:
            in_entry = False
            for line in f:
                line = line.rstrip()
                if line == '[Desktop Entry]':
                    in_entry = True
                elif line.startswith('[') and in_entry:
                    break
                elif in_entry and '=' in line:
                    k, _, v = line.partition('=')
                    if k not in d:
                        d[k] = v
    except Exception:
        pass
    if d.get('NoDisplay') == 'true':
        continue
    if d.get('Type', 'Application') != 'Application':
        continue
    if not d.get('Name') or not d.get('Exec'):
        continue
    result.append(d['Name'] + '\t' + d['Exec'] + '\t' + d.get('Icon', '') + '\t' + d.get('Terminal', 'false'))

result.sort(key=lambda x: x.lower())
sys.stdout.write('\n'.join(result) + '\n')
sys.stdout.flush()
