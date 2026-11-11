"""PoC HTTP portable. No implementa IIS, ARR, AD DS ni DNS de Windows."""
from __future__ import annotations
import argparse, csv, io, json, mimetypes, threading, time, urllib.request, urllib.error
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit, unquote

ROOT = Path(__file__).resolve().parents[1]

def utc():
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds")

def send(handler, code, body, content_type="application/json; charset=utf-8", extra=None):
    if isinstance(body, (dict, list)):
        body = json.dumps(body, ensure_ascii=False).encode()
    elif isinstance(body, str):
        body = body.encode()
    handler.send_response(code)
    handler.send_header("Content-Type", content_type)
    handler.send_header("Content-Length", str(len(body)))
    handler.send_header("Cache-Control", "no-store")
    handler.send_header("X-Content-Type-Options", "nosniff")
    for key, value in (extra or {}).items():
        handler.send_header(key, value)
    handler.end_headers()
    try:
        handler.wfile.write(body)
    except (BrokenPipeError, ConnectionResetError):
        pass

def static(handler, base, relative, extra=None):
    target = (base / unquote(urlsplit(relative).path).lstrip("/")).resolve()
    if not target.is_relative_to(base.resolve()):
        return send(handler, 403, {"error": "Ruta fuera del sitio"})
    if target.is_dir():
        target /= "index.html"
    if not target.is_file():
        return send(handler, 404, {"error": "No encontrado"})
    mime = mimetypes.guess_type(str(target))[0] or "application/octet-stream"
    send(handler, 200, target.read_bytes(), mime, extra)

class QuietHandler(BaseHTTPRequestHandler):
    def log_message(self, *_args):
        pass

class Lab:
    def __init__(self, port=8080, node_ports=(8081, 8082), interval=2.0, timeout=1.0, threshold=2):
        self.interval, self.timeout, self.threshold = interval, timeout, threshold
        self.lock = threading.RLock()
        self.stop_event = threading.Event()
        self.nodes = [dict(name=f"WEB0{i+1}", port=p, server=None, healthy=False,
                           failures=0, handled=0, last_check=None) for i, p in enumerate(node_ports)]
        self.records, self.events = [], []
        self.cursor, self.total, self.errors = 0, 0, 0
        self.gateway = ThreadingHTTPServer(("127.0.0.1", port), self.gateway_handler())
        self.gateway_started = False
        self.started_at = utc()

    @property
    def port(self):
        return self.gateway.server_address[1]

    def node_handler(self, node):
        class Backend(QuietHandler):
            def do_GET(self):
                static(self, ROOT / "web", self.path, {"X-Lab-Node": node["name"]})
        return Backend

    def set_running(self, index, running):
        with self.lock:
            node = self.nodes[index]
            current = node["server"]
            if bool(current) == running:
                return
            if running:
                server = ThreadingHTTPServer(("127.0.0.1", node["port"]), self.node_handler(node))
                node["port"] = server.server_address[1]
                node["server"] = server
                threading.Thread(target=server.serve_forever, kwargs={"poll_interval": .03}, daemon=True).start()
            else:
                node["server"] = None
            self.events.append(dict(utc=utc(), node=node["name"], action="start" if running else "stop"))
        if not running:
            current.shutdown()
            current.server_close()

    def check_once(self):
        for node in self.nodes:
            ok = False
            try:
                with urllib.request.urlopen(f"http://127.0.0.1:{node['port']}/health.html", timeout=self.timeout) as r:
                    ok = r.status == 200 and b"LAB_HEALTHY" in r.read()
            except (OSError, urllib.error.URLError):
                pass
            with self.lock:
                node["last_check"] = utc()
                node["failures"] = 0 if ok else node["failures"] + 1
                if ok or node["failures"] >= self.threshold:
                    node["healthy"] = ok

    def health_loop(self):
        while not self.stop_event.wait(self.interval):
            self.check_once()

    def snapshot(self):
        with self.lock:
            return dict(mode="portable-http-poc", implementation="Python stdlib; no IIS/ARR ni AD DS",
                        started_at=self.started_at, requests=self.total, errors=self.errors,
                        interval=self.interval, timeout=self.timeout, threshold=self.threshold,
                        nodes=[{k: v for k, v in n.items() if k != "server"} |
                               {"running": n["server"] is not None} for n in self.nodes], events=list(self.events))

    def proxy(self, handler):
        began = time.perf_counter()
        timestamp = utc()
        with self.lock:
            ready = [n for n in self.nodes if n["healthy"]]
            node = ready[self.cursor % len(ready)] if ready else None
            self.cursor += 1
        code, payload, mime, node_name, error = 503, b"No hay backend saludable", "text/plain; charset=utf-8", "", "no_healthy_backend"
        if node:
            node_name = node["name"]
            path = handler.path[len("/portal"): ] or "/"
            try:
                with urllib.request.urlopen(f"http://127.0.0.1:{node['port']}{path}", timeout=self.timeout) as r:
                    code, payload, mime = r.status, r.read(), r.headers.get("Content-Type", "text/plain")
                    error = ""
            except urllib.error.HTTPError as ex:
                code, payload, error = ex.code, ex.read(), f"backend_http_{ex.code}"
            except (OSError, urllib.error.URLError) as ex:
                code, payload, error = 502, b"Backend no disponible durante deteccion", type(ex).__name__
        elapsed = (time.perf_counter() - began) * 1000
        with self.lock:
            self.total += 1
            self.errors += int(code >= 400)
            if node:
                node["handled"] += 1
            self.records.append(dict(utc=timestamp, status=code, node=node_name,
                                     elapsed_ms=round(elapsed, 3), error=error, path=handler.path))
            self.records = self.records[-20000:]
        send(handler, code, payload, mime, {"X-Lab-Node": node_name or "NONE"})

    def gateway_handler(self):
        lab = self
        class Gateway(QuietHandler):
            def do_GET(self):
                path = urlsplit(self.path).path
                if path == "/api/status":
                    return send(self, 200, lab.snapshot())
                if path == "/api/evidence.csv":
                    with lab.lock:
                        records = list(lab.records)
                    buffer = io.StringIO(newline="")
                    writer = csv.DictWriter(buffer, fieldnames=["utc", "status", "node", "elapsed_ms", "error", "path"])
                    writer.writeheader(); writer.writerows(records)
                    return send(self, 200, buffer.getvalue(), "text/csv; charset=utf-8",
                                {"Content-Disposition": 'attachment; filename="portable-http.csv"'})
                if path.startswith("/portal/") or path == "/portal":
                    return lab.proxy(self)
                return static(self, ROOT / "docs", self.path)

            def do_POST(self):
                if urlsplit(self.path).path != "/api/control":
                    return send(self, 404, {"error": "No encontrado"})
                origin = self.headers.get("Origin")
                allowed = {f"http://127.0.0.1:{lab.port}", f"http://localhost:{lab.port}"}
                if origin and origin not in allowed:
                    return send(self, 403, {"error": "Origen no permitido"})
                # Un navegador de otro origen no puede enviar este encabezado sin preflight.
                if self.headers.get("X-Lab-Control") != "local-demo":
                    return send(self, 403, {"error": "Encabezado de control requerido"})
                try:
                    length = int(self.headers.get("Content-Length", "0"))
                    if not 0 < length <= 1024:
                        raise ValueError("Tamaño inválido")
                    data = json.loads(self.rfile.read(length))
                    index = [n["name"] for n in lab.nodes].index(data["node"])
                    if not isinstance(data["running"], bool):
                        raise ValueError("running debe ser booleano")
                    lab.set_running(index, data["running"])
                except (ValueError, KeyError, TypeError, json.JSONDecodeError) as ex:
                    return send(self, 400, {"error": str(ex)})
                return send(self, 200, lab.snapshot())
        return Gateway

    def start(self):
        try:
            for i in range(len(self.nodes)):
                self.set_running(i, True)
            self.check_once()
            threading.Thread(target=self.health_loop, daemon=True).start()
            threading.Thread(target=self.gateway.serve_forever, kwargs={"poll_interval": .03}, daemon=True).start()
            self.gateway_started = True
        except BaseException:
            self.close()
            raise
        return self

    def close(self):
        self.stop_event.set()
        for i in range(len(self.nodes)):
            if self.nodes[i]["server"]:
                self.set_running(i, False)
        if self.gateway_started:
            self.gateway.shutdown()
        self.gateway.server_close()

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--port", type=int, default=8080)
    p.add_argument("--web1-port", type=int, default=8081)
    p.add_argument("--web2-port", type=int, default=8082)
    args = p.parse_args()
    lab = Lab(args.port, (args.web1_port, args.web2_port)).start()
    print(f"PoC HTTP real y local: http://127.0.0.1:{lab.port}", flush=True)
    print("Servidores Python en loopback. Windows Server/AD DS aún requieren el laboratorio.", flush=True)
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        lab.close()

if __name__ == "__main__":
    main()
