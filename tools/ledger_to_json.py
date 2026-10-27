"""管理台帳(xlsx)から、アプリが読む assets/data/*.json を作る。

使い方: python3 tools/ledger_to_json.py 管理台帳_104回生.xlsx
台帳の「担当者名簿」「出典」「メモ」などはアプリに出さない（個人情報を持ち込まないため）。
"""
import json, sys, datetime, openpyxl

def s(v):
    if v is None: return ''
    if isinstance(v, (datetime.date, datetime.datetime)): return v.strftime('%Y-%m-%d')
    return str(v)

wb = openpyxl.load_workbook(sys.argv[1], data_only=True)
rows = list(wb['教材'].iter_rows(values_only=True))
h = rows[0]
materials = []
for r in rows[1:]:
    d = dict(zip(h, r))
    if not d['教材ID']: continue
    materials.append({
        'id': s(d['教材ID']), 'year': s(d['年度']), 'exam': s(d['試験名']),
        'subject': s(d['科目']), 'unit': s(d['単元']), 'kind': s(d['教材種別']),
        'method': s(d['作成方法']), 'check': s(d['内容確認']),
        'updated': s(d['最終更新日']), 'version': s(d['版']),
        # 閲覧制限つきの保存先（学校アカウントのDriveなど）のURL。空なら「準備中」と表示。
        'url': s(d['参照先URL']),
    })
rows = list(wb['日程・範囲'].iter_rows(values_only=True))
h = rows[0]
schedule = [{'exam': s(d['試験名']), 'date': s(d['実施日']), 'subject': s(d['科目']),
             'period': s(d['時限']), 'range': s(d['出題範囲'])}
            for d in (dict(zip(h, r)) for r in rows[1:]) if d['科目']]
dump = lambda p, o: open(p, 'w', encoding='utf-8').write(json.dumps(o, ensure_ascii=False, indent=1) + '\n')
dump('assets/data/materials.json', materials)
dump('assets/data/schedule.json', schedule)
print(len(materials), 'materials,', len(schedule), 'schedule rows')
