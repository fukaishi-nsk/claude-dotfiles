import json, sys, re, os
SP = os.path.dirname(os.path.abspath(__file__))
STATE = f"{SP}/assign_state.json"
def norm_sig(t, qty, tanka, taka, saki):
    t = re.sub(r'\s+', '', str(t))
    qty = str(int(float(qty))) if str(qty).strip() else ''
    tanka = re.sub(r'[^0-9]', '', str(tanka))
    taka = str(taka).strip().rstrip('m')
    if taka.endswith('.0'): taka = taka[:-2]
    saki = str(saki).strip().split('\n')[0]
    return f"{t}|{qty}|{tanka}|{taka}|{saki}"
if not os.path.exists(STATE):
    d = json.load(open(f"{SP}/sora_n8863-8911.json"))
    queues, expected = {}, {}
    for x in sorted(d, key=lambda v: v['n']):
        a = x['attrs']
        sig = norm_sig(x['title'], x['quantity'], a.get('仕入単価',''), a.get('樹高（鉢上）m',''), a.get('仕入れ先',''))
        queues.setdefault(sig, []).append(x['n'])
    st = {'queues': queues, 'assign': {}}
    json.dump(st, open(STATE,'w'), ensure_ascii=False, indent=1)
st = json.load(open(STATE))
uuid = sys.argv[1]; sig_raw = json.loads(sys.argv[2])
if uuid in st['assign']:
    print(st['assign'][uuid]); sys.exit(0)
sig = norm_sig(sig_raw.get('t',''), sig_raw.get('qty',''), sig_raw.get('tanka',''), sig_raw.get('taka',''), sig_raw.get('saki',''))
q = st['queues'].get(sig, [])
if not q:
    print(f"SIG_MISS:{sig}"); sys.exit(1)
n = q.pop(0); st['assign'][uuid] = n
json.dump(st, open(STATE,'w'), ensure_ascii=False, indent=1)
print(n)
