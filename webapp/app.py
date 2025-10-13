"""Simple Flask app that wraps the Debian system audit script with a web UI."""
from __future__ import annotations

import os
import pathlib
import subprocess
from datetime import datetime

from flask import Flask, jsonify, render_template

APP_ROOT = pathlib.Path(__file__).resolve().parent
REPO_ROOT = APP_ROOT.parent
SCRIPT_PATH = REPO_ROOT / "scripts" / "debian_system_audit.sh"
REPORT_DIR = APP_ROOT / "reports"
REPORT_DIR.mkdir(exist_ok=True)

app = Flask(__name__)


def _ensure_executable() -> None:
    """Ensure the audit script is executable so subprocess can run it."""
    if SCRIPT_PATH.exists() and not os.access(SCRIPT_PATH, os.X_OK):
        SCRIPT_PATH.chmod(SCRIPT_PATH.stat().st_mode | 0o111)


@app.route("/")
def index():
    return render_template("index.html", script_exists=SCRIPT_PATH.exists())


@app.route("/run", methods=["POST"])
def run_audit():
    if not SCRIPT_PATH.exists():
        return (
            jsonify({
                "ok": False,
                "message": "O script debian_system_audit.sh não foi encontrado.",
            }),
            404,
        )

    _ensure_executable()

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_path = REPORT_DIR / f"debian_system_audit_{timestamp}.log"

    env = os.environ.copy()
    env.setdefault("LC_ALL", "C.UTF-8")

    try:
        completed = subprocess.run(
            [str(SCRIPT_PATH), str(log_path)],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            env=env,
            cwd=str(REPORT_DIR),
            check=False,
        )
    except FileNotFoundError:
        return (
            jsonify({
                "ok": False,
                "message": "Não foi possível executar o script. Verifique se o Bash está disponível.",
            }),
            500,
        )
    except Exception as exc:  # pragma: no cover - defensive path
        return (
            jsonify({"ok": False, "message": f"Erro inesperado: {exc}"}),
            500,
        )

    payload = {
        "ok": completed.returncode == 0,
        "output": completed.stdout,
        "log_path": str(log_path),
        "return_code": completed.returncode,
    }
    if completed.returncode != 0:
        payload["message"] = (
            "O script terminou com código de retorno diferente de zero. Consulte a saída para detalhes."
        )

    return jsonify(payload)


@app.post("/clear-reports")
def clear_reports():
    """Remove relatórios antigos através da interface."""
    deleted = 0
    for path in REPORT_DIR.glob("*.log"):
        try:
            path.unlink()
            deleted += 1
        except OSError:
            continue
    return jsonify({"ok": True, "deleted": deleted})


if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=int(os.environ.get("PORT", 5000)))
