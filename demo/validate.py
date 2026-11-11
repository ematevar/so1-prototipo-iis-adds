"""Ejecuta un ensayo corto REAL de la PoC portable y conserva datos brutos."""
import csv, json, platform, time, urllib.request, urllib.error
from pathlib import Path
from demo.server import Lab, utc

def main():
    folder=Path(__file__).resolve().parents[1]/'evidence'/'portable'
    folder.mkdir(parents=True,exist_ok=True)
    lab=Lab(0,(0,0),interval=.1,timeout=.2,threshold=2).start()
    base=f'http://127.0.0.1:{lab.port}'
    observations=[]
    def sample(stage,count):
        for _ in range(count):
            began=time.perf_counter();status=0;node='';error=''
            try:
                with urllib.request.urlopen(base+'/portal/health.html',timeout=2) as r:
                    status=r.status;node=r.headers.get('X-Lab-Node','');r.read()
            except urllib.error.HTTPError as ex:
                status=ex.code;node=ex.headers.get('X-Lab-Node','');error=f'HTTP {ex.code}'
            except OSError as ex:
                error=type(ex).__name__
            observations.append(dict(utc=utc(),status=status,node=node,elapsed_ms=round((time.perf_counter()-began)*1000,3),stage=stage,error=error))
            time.sleep(.05)
    started=utc()
    try:
        sample('baseline_two_backends',20)
        lab.set_running(0,False);sample('WEB01_stopped',30)
        lab.set_running(0,True);sample('WEB01_restarted',20)
        lab.set_running(0,False);lab.set_running(1,False);time.sleep(.35);sample('both_stopped',5)
        snap=lab.snapshot()
    finally:
        lab.close()
    with (folder/'requests.csv').open('w',encoding='utf-8',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(observations[0]));w.writeheader();w.writerows(observations)
    stages={}
    for name in sorted({s['stage'] for s in observations}):
        rows=[s for s in observations if s['stage']==name];lat=sorted(s['elapsed_ms'] for s in rows)
        stages[name]=dict(requests=len(rows),failed=sum(s['status']>=400 or s['status']==0 for s in rows),nodes=sorted({s['node'] for s in rows if s['node']}),p95_ms=lat[max(0,__import__('math').ceil(.95*len(lat))-1)])
    passed=(set(stages['baseline_two_backends']['nodes'])=={'WEB01','WEB02'} and observations[49]['node']=='WEB02' and stages['both_stopped']['failed']==5)
    report=dict(source='PoC HTTP portable; Python stdlib. NO es evidencia de IIS/ARR/AD DS.',started_utc=started,platform=platform.platform(),python=platform.python_version(),health_interval=.1,health_timeout=.2,failure_threshold=2,passed=passed,stages=stages,events=snap['events'],scope='Ensayo corto local con puertos efímeros; no satisface la campaña de 300 s ni las pruebas de dominio de la Unidad III.')
    (folder/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(report,ensure_ascii=False,indent=2))
    if not passed:raise SystemExit(1)

if __name__=='__main__':main()
