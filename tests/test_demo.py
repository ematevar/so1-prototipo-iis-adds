import json, time, unittest, urllib.request, urllib.error
from demo.server import Lab

class HttpPrototypeTests(unittest.TestCase):
    def setUp(self):
        self.lab = Lab(0, (0, 0), interval=.03, timeout=.1, threshold=1).start()
        self.base = f"http://127.0.0.1:{self.lab.port}"

    def tearDown(self):
        self.lab.close()

    def get(self, path):
        try:
            with urllib.request.urlopen(self.base + path, timeout=2) as r:
                return r.status, r.headers, r.read()
        except urllib.error.HTTPError as ex:
            return ex.code, ex.headers, ex.read()

    def wait_health(self, count):
        until = time.monotonic() + 3
        while time.monotonic() < until:
            if sum(n["healthy"] for n in self.lab.snapshot()["nodes"]) == count:
                return
            time.sleep(.02)
        self.fail("El estado de salud no convergió")

    def test_round_robin_and_header(self):
        nodes = [self.get('/portal/health.html')[1]['X-Lab-Node'] for _ in range(8)]
        self.assertEqual(nodes, ['WEB01', 'WEB02'] * 4)

    def test_real_stop_failover_reintegration(self):
        self.lab.set_running(0, False)
        self.wait_health(1)
        for _ in range(5):
            code, headers, _ = self.get('/portal/health.html')
            self.assertEqual((code, headers['X-Lab-Node']), (200, 'WEB02'))
        self.lab.set_running(0, True)
        self.wait_health(2)
        self.assertEqual({self.get('/portal/health.html')[1]['X-Lab-Node'] for _ in range(4)}, {'WEB01','WEB02'})

    def test_no_healthy_backend_is_503(self):
        self.lab.set_running(0, False); self.lab.set_running(1, False)
        self.wait_health(0)
        self.assertEqual(self.get('/portal/health.html')[0], 503)

    def test_control_requires_header_and_same_origin(self):
        payload = json.dumps({'node':'WEB01','running':False}).encode()
        for headers in [{'Content-Type':'application/json'}, {'X-Lab-Control':'local-demo','Origin':'https://untrusted.invalid'}]:
            req = urllib.request.Request(self.base+'/api/control', data=payload, headers=headers)
            with self.assertRaises(urllib.error.HTTPError) as cm:
                urllib.request.urlopen(req, timeout=2)
            self.assertEqual(cm.exception.code,403)

    def test_control_can_stop_a_node(self):
        req = urllib.request.Request(self.base+'/api/control',data=b'{"node":"WEB01","running":false}',headers={'X-Lab-Control':'local-demo','Content-Type':'application/json'})
        with urllib.request.urlopen(req,timeout=2) as r:
            result=json.load(r)
        self.assertFalse(result['nodes'][0]['running'])

    def test_static_traversal_is_blocked(self):
        self.assertEqual(self.get('/%2e%2e/README.md')[0],403)

    def test_export_is_measured_csv(self):
        self.get('/portal/health.html')
        code, _, data=self.get('/api/evidence.csv')
        self.assertEqual(code,200)
        self.assertIn(b'utc,status,node,elapsed_ms,error,path',data)
        self.assertIn(b'WEB01',data)

if __name__=='__main__':
    unittest.main()
