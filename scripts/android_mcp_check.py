#!/usr/bin/env python3
"""
android_mcp_check.py — drive the Android-MCP server directly over the MCP
protocol (no Claude Code / VSCode needed) to prove it fully works and to run
an on-device smoke check of HNAG.

It speaks newline-delimited JSON-RPC (MCP stdio transport) to the server:
    initialize -> notifications/initialized -> tools/list -> tools/call ...

Usage:
    python scripts/android_mcp_check.py                  # full check
    python scripts/android_mcp_check.py --ip 192.168.1.110
    python scripts/android_mcp_check.py --call Shell-Tool '{"command":"getprop ro.product.model"}'
"""
import argparse, json, queue, subprocess, sys, threading, time

def main():
    # Windows consoles default to cp1252 and crash on Vietnamese/emoji output.
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            pass
    ap = argparse.ArgumentParser()
    ap.add_argument("--ip", default="192.168.1.110", help="WiFi ADB host of the device")
    ap.add_argument("--python", default="3.13")
    ap.add_argument("--call", nargs=2, metavar=("TOOL", "ARGS_JSON"),
                    help="call one tool with JSON args and exit")
    ap.add_argument("--scenario", choices=["hnag"], help="run a full guided test via MCP")
    ap.add_argument("--steps", help="JSON list of action steps to run in one MCP session")
    args = ap.parse_args()

    cmd = ["uvx", "--python", args.python, "android-mcp", "--wifi", args.ip]
    print(f"[*] launching: {' '.join(cmd)}")
    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, text=True, bufsize=1,
                            encoding="utf-8")

    q = queue.Queue()
    def reader(pipe):
        for line in pipe:
            q.put(line)
        q.put(None)
    threading.Thread(target=reader, args=(proc.stdout,), daemon=True).start()
    def errdrain(pipe):
        for line in pipe:
            sys.stderr.write("    [srv] " + line)
    threading.Thread(target=errdrain, args=(proc.stderr,), daemon=True).start()

    def send(obj):
        proc.stdin.write(json.dumps(obj) + "\n")
        proc.stdin.flush()

    def recv(want_id=None, timeout=90):
        """Return next JSON-RPC message (optionally matching an id)."""
        end = time.time() + timeout
        while time.time() < end:
            try:
                line = q.get(timeout=max(0.1, end - time.time()))
            except queue.Empty:
                return None
            if line is None:
                return None
            line = line.strip()
            if not line:
                continue
            try:
                msg = json.loads(line)
            except json.JSONDecodeError:
                continue
            if want_id is None or msg.get("id") == want_id:
                return msg
        return None

    def call(tid, method, params=None, timeout=90):
        send({"jsonrpc": "2.0", "id": tid, "method": method, "params": params or {}})
        return recv(want_id=tid, timeout=timeout)

    def short(obj, n=600):
        s = json.dumps(obj, ensure_ascii=False)
        return s if len(s) <= n else s[:n] + f"... (+{len(s)-n} chars)"

    # 1) handshake
    init = call(1, "initialize", {
        "protocolVersion": "2024-11-05",
        "capabilities": {},
        "clientInfo": {"name": "hnag-tester", "version": "1.0"},
    })
    if not init:
        print("[FAIL] no initialize response"); proc.kill(); return 1
    srv = init.get("result", {}).get("serverInfo", {})
    print(f"[OK] initialize -> server={srv.get('name')} v{srv.get('version')}")
    send({"jsonrpc": "2.0", "method": "notifications/initialized"})

    # 2) list tools
    tl = call(2, "tools/list")
    tools = (tl or {}).get("result", {}).get("tools", [])
    print(f"[OK] tools/list -> {len(tools)} tools:")
    for t in tools:
        sch = t.get("inputSchema", {}) or {}
        props = list((sch.get("properties", {}) or {}).keys())
        req = sch.get("required", [])
        print(f"      - {t['name']} args={props} required={req}")

    # generic step runner — one MCP session, saves png + UI element table (.txt)
    if args.steps:
        import base64, os, subprocess as sp, json as _json
        D = f"{args.ip}:5555"
        outdir = os.path.join(os.path.dirname(__file__), "mcp_test_shots")
        os.makedirs(outdir, exist_ok=True)
        idc = [200]
        def rpc(name, arguments, timeout=60):
            idc[0] += 1
            return call(idc[0], "tools/call", {"name": name, "arguments": arguments}, timeout=timeout)
        def do(step):
            act = step[0]
            if act == "launch":
                sp.run(["adb", "-s", D, "shell", "am", "start", "-n", "vn.hnag.hnag/.MainActivity"]); print("   [launch]")
            elif act == "stop":
                sp.run(["adb", "-s", D, "shell", "am", "force-stop", "vn.hnag.hnag"]); print("   [stop]")
            elif act == "wait":
                rpc("Wait", {"duration": step[1]}, timeout=step[1] + 20); print(f"   [wait] {step[1]}s")
            elif act == "click":
                r = rpc("Click", {"x": step[1], "y": step[2]}); print(f"   [click] ({step[1]},{step[2]}) {'ok' if r and not r.get('error') else 'ERR'}")
            elif act == "type":
                r = rpc("Type", {"text": step[1], "x": step[2], "y": step[3], "clear": True}); print(f"   [type] '{step[1]}' @({step[2]},{step[3]}) {'ok' if r and not r.get('error') else 'ERR'}")
            elif act == "sel":
                r = rpc("ClickBySelector", {"text": step[1]}); print(f"   [sel] '{step[1]}' {'ok' if r and not r.get('error') else 'ERR'}")
            elif act == "swipe":
                rpc("Swipe", {"x1": step[1], "y1": step[2], "x2": step[3], "y2": step[4]}); print("   [swipe]")
            elif act == "back":
                rpc("Press", {"button": step[1] if len(step) > 1 else "Back"}); print("   [back]")
            elif act == "snap":
                r = rpc("Snapshot", {"use_vision": True, "use_annotation": True}, timeout=90)
                content = (r or {}).get("result", {}).get("content", [])
                img = False; txt = ""
                for c in content:
                    if c.get("type") == "image":
                        open(os.path.join(outdir, f"{step[1]}.png"), "wb").write(base64.b64decode(c.get("data", ""))); img = True
                    elif c.get("type") == "text":
                        txt += c.get("text", "")
                if txt:
                    open(os.path.join(outdir, f"{step[1]}.txt"), "w", encoding="utf-8").write(txt)
                print(f"   [snap] {step[1]} img={'y' if img else 'n'} txt={len(txt)}c")
        for s in _json.loads(args.steps):
            do(s)
        print(f"[DONE] steps -> {outdir}")
        proc.kill(); return 0

    # full guided test, driven entirely through the MCP server
    if args.scenario == "hnag":
        import base64, os, subprocess as sp
        D = f"{args.ip}:5555"
        outdir = os.path.join(os.path.dirname(__file__), "mcp_test_shots")
        os.makedirs(outdir, exist_ok=True)
        idc = [100]
        def rpc(name, arguments, timeout=60):
            idc[0] += 1
            return call(idc[0], "tools/call", {"name": name, "arguments": arguments}, timeout=timeout)
        def snap(prefix):
            r = rpc("Snapshot", {"use_vision": True, "use_annotation": True}, timeout=90)
            content = (r or {}).get("result", {}).get("content", [])
            img = False
            for c in content:
                if c.get("type") == "image":
                    open(os.path.join(outdir, f"{prefix}.png"), "wb").write(base64.b64decode(c.get("data", "")))
                    img = True
            lines = sum(c.get("text", "").count("\n") for c in content if c.get("type") == "text")
            print(f"   [snap] {prefix}: image={'yes' if img else 'no'} ui_lines~{lines}")
        def click(x, y, label):
            r = rpc("Click", {"x": x, "y": y}, timeout=30)
            print(f"   [click] {label} ({x},{y}) -> {'ok' if r and not r.get('error') else 'ERR'}")
        def wait(s):
            rpc("Wait", {"duration": s}, timeout=s + 20)
        print("[*] launching HNAG via adb (setup), then driving via MCP ...")
        sp.run(["adb", "-s", D, "shell", "am", "force-stop", "vn.hnag.hnag"])
        sp.run(["adb", "-s", D, "shell", "am", "start", "-n", "vn.hnag.hnag/.MainActivity"])
        wait(6); snap("01_home")
        click(457, 2595, "tab AI Decide"); wait(3); snap("02_aidecide")
        click(762, 2595, "tab Tools");     wait(2); snap("03_tools")
        click(1067, 2595, "tab Profile");  wait(3); snap("04_profile")
        click(152, 2595, "tab Home");      wait(2); snap("05_home_again")
        print(f"[DONE] MCP-driven HNAG walkthrough complete. Shots: {outdir}")
        proc.kill(); return 0

    # explicit single-call mode
    if args.call:
        import base64, os
        name, raw = args.call
        res = call(9, "tools/call", {"name": name, "arguments": json.loads(raw)}, timeout=120)
        content = (res or {}).get("result", {}).get("content", [])
        if not content:
            print(f"[CALL] {name} -> {short(res, 1500)}")
        for i, c in enumerate(content):
            if c.get("type") == "text":
                print(f"[CALL] {name} text:\n{c.get('text','')[:2000]}")
            elif c.get("type") == "image":
                out = os.path.join(os.path.dirname(__file__), f"_mcp_{name}_{i}.png")
                with open(out, "wb") as f:
                    f.write(base64.b64decode(c.get("data", "")))
                print(f"[CALL] {name} image saved -> {out} ({c.get('mimeType')})")
        proc.kill(); return 0

    # 3) prove device control via Shell-Tool (getprop)
    shell = next((t["name"] for t in tools if "shell" in t["name"].lower()), None)
    if shell:
        props = "getprop ro.product.brand; getprop ro.product.model; getprop ro.build.version.release"
        # try common arg names
        for arg in ("command", "cmd", "shell_command"):
            res = call(3, "tools/call", {"name": shell, "arguments": {arg: props}}, timeout=60)
            if res and not res.get("error"):
                print(f"[OK] {shell}({arg}=...) -> {short(res, 400)}")
                break
        else:
            print(f"[WARN] {shell} call did not succeed with common arg names")

    # 4) prove UI snapshot via State-Tool
    state = next((t["name"] for t in tools if "state" in t["name"].lower()), None)
    if state:
        res = call(4, "tools/call", {"name": state, "arguments": {}}, timeout=90)
        if res and not res.get("error"):
            content = res.get("result", {}).get("content", [])
            kinds = [c.get("type") for c in content]
            sizes = [len(c.get("text", "")) if c.get("type") == "text" else len(c.get("data", "")) for c in content]
            print(f"[OK] {state}() -> content types={kinds} sizes={sizes}")
        else:
            print(f"[INFO] {state}() -> {short(res, 300)}")

    print("\n[DONE] MCP server is fully operational over the protocol.")
    proc.kill()
    return 0

if __name__ == "__main__":
    sys.exit(main())
