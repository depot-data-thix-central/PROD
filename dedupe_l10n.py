import re, os

os.chdir('lib/l10n')

GETTER = re.compile(r'^\s*@override\s+String\s+get\s+(\w+)\s*=>')

files = [
    'app_localizations_fr.dart',
    'app_localizations_en.dart',
    'app_localizations_pt.dart',
    'app_localizations_sw.dart',
    'app_localizations_ar.dart',
    'app_localizations_zh.dart',
]

for path in files:
    if not os.path.exists(path):
        continue
    with open(path, encoding='utf-8') as f:
        lines = f.readlines()

    seen = set()
    out = []
    removed = 0
    for line in lines:
        m = GETTER.match(line)
        if m:
            name = m.group(1)
            if name in seen:
                removed += 1
                continue          # ⛔ supprime le doublon (garde la 1ʳ occurrence)
            seen.add(name)
        out.append(line)

    with open(path, 'w', encoding='utf-8') as f:
        f.writelines(out)
    print(f'✅ {path}: {removed} doublon(s) supprimé(s)')
