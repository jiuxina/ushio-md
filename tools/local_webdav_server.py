#!/usr/bin/env python3
"""Local WebDAV server used to test Ushio-MD cloud sync.

This is a deliberately small WebDAV implementation covering the operations
used by ``lib/services/webdav_service.dart``:

* OPTIONS - connection ping
* PROPFIND - list directory contents (depth 0/1)
* MKCOL - create directories
* PUT - upload files
* GET - download files
* DELETE - remove files/directories

It supports HTTP Basic auth and maps every request path to a local directory.

Usage:
    python tools/local_webdav_server.py --port 18080 --dir .local_webdav \
        --user test --password test
"""

from __future__ import annotations

import argparse
import base64
import email.utils
import hashlib
import mimetypes
import os
import shutil
import sys
import urllib.parse
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


def _reject_insecure_root(root: Path) -> None:
    """Refuse to serve the host's own storage locations."""
    resolved = root.resolve()
    lowered = str(resolved).lower()

    drive_roots: set[str] = set()
    for letter in "abcdefghijklmnopqrstuvwxyz":
        drive = Path(f"{letter}:\\")
        if drive.exists():
            drive_roots.add(str(drive.resolve()).lower())
    home = Path.home().resolve()
    personal_dirs = [
        home,
        home / "Documents",
        home / "Desktop",
        home / "Downloads",
        home / "Pictures",
        home / "Videos",
        home / "Music",
    ]
    blocked = {str(p.resolve()).lower() for p in personal_dirs} | drive_roots
    if lowered in blocked:
        raise SystemExit(
            f"Refusing to serve {resolved}: this looks like host storage. "
            "Pass a dedicated --dir such as a temp or sandbox directory."
        )


class LocalWebDAVHandler(BaseHTTPRequestHandler):
    """WebDAV request handler backed by a local directory."""

    server_version = "LocalWebDAV/1.0"

    def _require_auth(self) -> bool:
        """Return True when the request carries valid Basic credentials."""
        expected = f"{self.server.username}:{self.server.password}".encode("utf-8")
        expected_b64 = base64.b64encode(expected).decode("ascii")
        header = self.headers.get("Authorization", "")
        if header == f"Basic {expected_b64}":
            return True
        self.send_response(401)
        self.send_header("WWW-Authenticate", 'Basic realm="local-webdav"')
        self.send_header("Content-Length", "0")
        self.end_headers()
        return False

    def _resolve(self) -> Path | None:
        """Resolve the request path to a file inside the server root."""
        raw_path = self.path.split("?", 1)[0]
        decoded = urllib.parse.unquote(raw_path)
        segments = [seg for seg in decoded.split("/") if seg not in ("", ".")]
        if any(seg == ".." for seg in segments):
            self.send_error(403, "Forbidden")
            return None

        root = Path(self.server.root).resolve()
        target = root.joinpath(*segments).resolve()
        if target != root and root not in target.parents:
            self.send_error(403, "Forbidden")
            return None
        real_root = os.path.realpath(root)
        real_target = os.path.realpath(target)
        if real_target != real_root and not real_target.startswith(
            real_root + os.sep
        ):
            self.send_error(403, "Forbidden")
            return None
        return Path(real_target)

    @staticmethod
    def _href(prefix: str, name: str, is_dir: bool) -> str:
        escaped = urllib.parse.quote(name)
        if prefix.endswith("/"):
            return f"{prefix}{escaped}{'/' if is_dir else ''}"
        return f"{prefix}/{escaped}{'/' if is_dir else ''}"

    @staticmethod
    def _http_date(timestamp: float) -> str:
        return email.utils.formatdate(timestamp, usegmt=True)

    @staticmethod
    def _prop_xml(href: str, stat: os.stat_result, is_dir: bool) -> str:
        name = urllib.parse.unquote(href.rstrip("/").rsplit("/", 1)[-1]) or "/"
        resource_type = "<d:collection/>" if is_dir else ""
        size = "0" if is_dir else str(stat.st_size)
        mtime = LocalWebDAVHandler._http_date(stat.st_mtime)
        mime = "httpd/unix-directory" if is_dir else (
            mimetypes.guess_type(name)[0] or "application/octet-stream"
        )
        return (
            "<d:response>"
            f"<d:href>{href}</d:href>"
            "<d:propstat><d:prop>"
            f"<d:displayname>{name}</d:displayname>"
            f"<d:resourcetype>{resource_type}</d:resourcetype>"
            f"<d:getcontentlength>{size}</d:getcontentlength>"
            f"<d:getcontenttype>{mime}</d:getcontenttype>"
            f"<d:getetag>\"{hashlib.md5(name.encode('utf-8')).hexdigest()}\"</d:getetag>"
            f"<d:getlastmodified>{mtime}</d:getlastmodified>"
            "</d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat>"
            "<d:propstat><d:prop>"
            "<d:creationdate/>"
            "</d:prop><d:status>HTTP/1.1 404 Not Found</d:status></d:propstat>"
            "</d:response>"
        )

    def _send_xml(self, body: str, status: int = 207) -> None:
        data = body.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", 'application/xml; charset="utf-8"')
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_OPTIONS(self) -> None:  # noqa: N802 (http.server API)
        if not self._require_auth():
            return
        self.send_response(200)
        self.send_header("DAV", "1, 2")
        self.send_header(
            "Allow", "OPTIONS, PROPFIND, MKCOL, PUT, GET, HEAD, DELETE"
        )
        self.send_header("MS-Author-Via", "DAV")
        self.send_header("Content-Length", "0")
        self.end_headers()

    def do_PROPFIND(self) -> None:  # noqa: N802
        if not self._require_auth():
            return
        target = self._resolve()
        if target is None:
            return
        if not target.exists():
            self.send_error(404, "Not Found")
            return

        is_dir = target.is_dir()
        depth = self.headers.get("Depth", "1").strip().lower()
        prefix = self.path.split("?", 1)[0].rstrip("/") or "/"
        if is_dir:
            prefix += "/"

        entries: list[tuple[str, os.stat_result, bool]] = [
            (prefix, target.stat(), is_dir)
        ]
        if is_dir and depth != "0":
            for child in sorted(target.iterdir(), key=lambda p: p.name.lower()):
                entries.append(
                    (
                        self._href(prefix, child.name, child.is_dir()),
                        child.stat(),
                        child.is_dir(),
                    )
                )

        responses = "".join(
            self._prop_xml(href, stat, child_is_dir)
            for href, stat, child_is_dir in entries
        )
        body = (
            '<?xml version="1.0" encoding="utf-8"?>'
            '<d:multistatus xmlns:d="DAV:">'
            f"{responses}</d:multistatus>"
        )
        self._send_xml(body)

    def do_MKCOL(self) -> None:  # noqa: N802
        if not self._require_auth():
            return
        target = self._resolve()
        if target is None:
            return
        if target.exists():
            self.send_response(405)
            self.send_header("Content-Length", "0")
            self.end_headers()
            return
        if not target.parent.exists():
            self.send_error(409, "Conflict")
            return
        try:
            target.mkdir()
            self.send_response(201)
            self.send_header("Content-Length", "0")
            self.end_headers()
        except OSError as exc:
            self.send_error(500, str(exc))

    def do_PUT(self) -> None:  # noqa: N802
        if not self._require_auth():
            return
        target = self._resolve()
        if target is None:
            return
        if target.is_dir():
            self.send_error(405, "Method Not Allowed")
            return
        try:
            target.parent.mkdir(parents=True, exist_ok=True)
            content_length = int(self.headers.get("Content-Length", "0"))
            with target.open("wb") as handle:
                remaining = content_length
                while remaining > 0:
                    chunk = self.rfile.read(min(1024 * 1024, remaining))
                    if not chunk:
                        break
                    handle.write(chunk)
                    remaining -= len(chunk)
            self.send_response(201 if content_length > 0 else 204)
            self.send_header("Content-Length", "0")
            self.end_headers()
        except OSError as exc:
            self.send_error(500, str(exc))

    def do_GET(self) -> None:  # noqa: N802
        if not self._require_auth():
            return
        target = self._resolve()
        if target is None:
            return
        if not target.is_file():
            self.send_error(404, "Not Found")
            return
        stat = target.stat()
        self.send_response(200)
        self.send_header(
            "Content-Type", mimetypes.guess_type(target.name)[0]
            or "application/octet-stream"
        )
        self.send_header("Content-Length", str(stat.st_size))
        self.end_headers()
        with target.open("rb") as handle:
            shutil.copyfileobj(handle, self.wfile)

    def do_HEAD(self) -> None:  # noqa: N802
        if not self._require_auth():
            return
        target = self._resolve()
        if target is None:
            return
        if not target.is_file():
            self.send_error(404, "Not Found")
            return
        stat = target.stat()
        self.send_response(200)
        self.send_header(
            "Content-Type", mimetypes.guess_type(target.name)[0]
            or "application/octet-stream"
        )
        self.send_header("Content-Length", str(stat.st_size))
        self.end_headers()

    def do_DELETE(self) -> None:  # noqa: N802
        if not self._require_auth():
            return
        target = self._resolve()
        if target is None:
            return
        if not target.exists():
            self.send_response(404)
            self.send_header("Content-Length", "0")
            self.end_headers()
            return
        try:
            if target.is_dir():
                shutil.rmtree(target)
            else:
                target.unlink()
            self.send_response(204)
            self.send_header("Content-Length", "0")
            self.end_headers()
        except OSError as exc:
            self.send_error(500, str(exc))

    def log_message(self, fmt: str, *args: object) -> None:
        timestamp = datetime.now(timezone.utc).isoformat(timespec="seconds")
        print(f"[{timestamp}] {self.address_string()} - {fmt % args}", flush=True)


class LocalWebDAVServer(ThreadingHTTPServer):
    """Threaded server carrying the root path and credentials."""

    daemon_threads = True

    def __init__(
        self,
        address: tuple[str, int],
        root: Path,
        username: str,
        password: str,
    ) -> None:
        self.root = str(root.resolve())
        self.username = username
        self.password = password
        super().__init__(address, LocalWebDAVHandler)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="0.0.0.0", help="bind host")
    parser.add_argument("--port", type=int, default=18080, help="bind port")
    parser.add_argument(
        "--dir", default=".local_webdav", help="directory served by WebDAV"
    )
    parser.add_argument("--user", default="test", help="Basic auth username")
    parser.add_argument("--password", default="test", help="Basic auth password")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    root = Path(args.dir).resolve()
    _reject_insecure_root(root)
    root.mkdir(parents=True, exist_ok=True)
    server = LocalWebDAVServer(
        (args.host, args.port), root, args.user, args.password
    )
    print(
        f"Local WebDAV listening on http://{args.host}:{args.port} "
        f"(root={root}, user={args.user})",
        flush=True,
    )
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
