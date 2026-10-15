"""
Servidor HTTP local assíncrono/threaded (127.0.0.1) para servir e fazer proxy de áudio.
Resolve problemas no Android:
- file:// URIs e falta de suporte a Range / MIME types em players nativos (ExoPlayer/MediaPlayer).
- HTTP 403 Forbidden no YouTube ao repassar User-Agent, Cookies e headers do yt-dlp.
"""

from __future__ import annotations

import http.server
import logging
import os
import secrets
import threading
import urllib.parse
import urllib.request
from typing import Any

logger = logging.getLogger(__name__)


def detect_audio_mime_type(file_path: str) -> str:
    """Detecta o MIME type de áudio via magic bytes ou extensão de fallback."""
    try:
        with open(file_path, "rb") as f:
            header = f.read(16)
        if len(header) >= 8 and header[4:8] in (b"ftyp", b"moov"):
            return "audio/mp4"
        if header.startswith(b"\x1a\x45\xdf\xa3"):
            return "audio/webm"
        if header.startswith(b"ID3") or (len(header) >= 2 and header[0] == 0xFF and (header[1] & 0xE0) == 0xE0):
            return "audio/mpeg"
        if header.startswith(b"OggS"):
            return "audio/ogg"
        if header.startswith(b"fLaC"):
            return "audio/flac"
        if header.startswith(b"RIFF") and len(header) >= 12 and header[8:12] == b"WAVE":
            return "audio/wav"
    except Exception:
        pass

    ext = os.path.splitext(file_path)[1].lower()
    if ext in (".m4a", ".mp4", ".aac"):
        return "audio/mp4"
    if ext in (".webm", ".weba"):
        return "audio/webm"
    if ext == ".mp3":
        return "audio/mpeg"
    if ext == ".ogg":
        return "audio/ogg"
    if ext == ".flac":
        return "audio/flac"
    if ext == ".wav":
        return "audio/wav"
    return "audio/mp4"


class _AudioRequestHandler(http.server.BaseHTTPRequestHandler):
    server: "LocalAudioServer"  # type hint para o servidor dono

    def log_message(self, format: str, *args: Any) -> None:
        # Silencia logs de requisições rotineiras
        pass

    def do_HEAD(self) -> None:
        self._handle_request(send_body=False)

    def do_GET(self) -> None:
        self._handle_request(send_body=True)

    def _handle_request(self, send_body: bool) -> None:
        parsed = urllib.parse.urlparse(self.path)
        parts = parsed.path.strip("/").split("/")

        if len(parts) >= 2 and parts[0] == "local":
            token = parts[1]
            self._handle_local(token, send_body)
        elif len(parts) >= 2 and parts[0] == "stream":
            token = parts[1]
            self._handle_stream(token, send_body)
        else:
            self.send_error(404, "Not Found")

    def _handle_local(self, token: str, send_body: bool) -> None:
        file_path = self.server.get_local_file(token)
        if not file_path or not os.path.isfile(file_path):
            self.send_error(404, "File Not Found")
            return

        try:
            file_size = os.path.getsize(file_path)
        except OSError:
            self.send_error(500, "Error reading file size")
            return

        content_type = detect_audio_mime_type(file_path)
        range_header = self.headers.get("Range")

        start = 0
        end = file_size - 1
        status_code = 200

        if range_header and range_header.startswith("bytes="):
            ranges = range_header[6:].split("-")
            try:
                if ranges[0]:
                    start = int(ranges[0])
                if len(ranges) > 1 and ranges[1]:
                    end = int(ranges[1])
                if start > end or start >= file_size:
                    self.send_response(416, "Requested Range Not Satisfiable")
                    self.send_header("Content-Range", f"bytes */{file_size}")
                    self.end_headers()
                    return
                end = min(end, file_size - 1)
                status_code = 206
            except ValueError:
                start = 0
                end = file_size - 1
                status_code = 200

        content_length = end - start + 1

        self.send_response(status_code)
        self.send_header("Content-Type", content_type)
        self.send_header("Accept-Ranges", "bytes")
        self.send_header("Content-Length", str(content_length))
        if status_code == 206:
            self.send_header("Content-Range", f"bytes {start}-{end}/{file_size}")
        self.end_headers()

        if not send_body:
            return

        chunk_size = 64 * 1024
        try:
            with open(file_path, "rb") as f:
                f.seek(start)
                bytes_left = content_length
                while bytes_left > 0:
                    read_len = min(chunk_size, bytes_left)
                    data = f.read(read_len)
                    if not data:
                        break
                    self.wfile.write(data)
                    bytes_left -= len(data)
        except (BrokenPipeError, ConnectionResetError):
            pass
        except Exception as exc:
            logger.debug("Erro ao servir arquivo local: %s", exc)

    def _handle_stream(self, token: str, send_body: bool) -> None:
        stream_info = self.server.get_stream_info(token)
        if not stream_info:
            self.send_error(404, "Stream Not Found")
            return

        target_url = stream_info.get("url")
        custom_headers = dict(stream_info.get("headers") or {})
        if not target_url:
            self.send_error(404, "Target URL missing")
            return

        req_headers: dict[str, str] = {}
        for k, v in custom_headers.items():
            req_headers[k] = str(v)

        range_header = self.headers.get("Range")
        if range_header:
            req_headers["Range"] = range_header

        req = urllib.request.Request(target_url, headers=req_headers, method="HEAD" if not send_body else "GET")

        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                code = resp.status if hasattr(resp, "status") else resp.getcode()
                self.send_response(code)

                # Repassa headers relevantes para o ExoPlayer/MediaPlayer
                for header_key in ("Content-Type", "Content-Length", "Accept-Ranges", "Content-Range"):
                    val = resp.headers.get(header_key)
                    if val:
                        self.send_header(header_key, val)
                self.end_headers()

                if not send_body:
                    return

                chunk_size = 64 * 1024
                while True:
                    chunk = resp.read(chunk_size)
                    if not chunk:
                        break
                    self.wfile.write(chunk)
        except urllib.error.HTTPError as exc:
            try:
                self.send_response(exc.code)
                for header_key in ("Content-Type", "Content-Length", "Content-Range"):
                    val = exc.headers.get(header_key)
                    if val:
                        self.send_header(header_key, val)
                self.end_headers()
                if send_body:
                    err_body = exc.read()
                    self.wfile.write(err_body)
            except Exception:
                pass
        except (BrokenPipeError, ConnectionResetError):
            pass
        except Exception as exc:
            logger.debug("Erro no proxy de stream: %s", exc)
            try:
                self.send_error(502, f"Bad Gateway: {exc}")
            except Exception:
                pass


class LocalAudioServer(http.server.ThreadingHTTPServer):
    """ThreadingHTTPServer local na porta 127.0.0.1 com armazenamento thread-safe de tokens."""

    def __init__(self, host: str = "127.0.0.1", port: int = 0):
        super().__init__((host, port), _AudioRequestHandler)
        self.lock = threading.Lock()
        self._local_files: dict[str, str] = {}
        self._streams: dict[str, dict[str, Any]] = {}
        self._server_thread: threading.Thread | None = None

    def start(self) -> None:
        if self._server_thread is None:
            self._server_thread = threading.Thread(target=self.serve_forever, daemon=True)
            self._server_thread.start()

    def stop(self) -> None:
        self.shutdown()
        self.server_close()

    @property
    def base_url(self) -> str:
        host, port = self.server_address
        return f"http://{host}:{port}"

    def register_local_file(self, file_path: str) -> str:
        """Registra um arquivo local e retorna a URL http://127.0.0.1:<port>/local/<token>/<filename>."""
        token = secrets.token_urlsafe(16)
        abs_path = os.path.abspath(file_path)
        with self.lock:
            self._local_files[token] = abs_path
        filename = urllib.parse.quote(os.path.basename(abs_path))
        return f"{self.base_url}/local/{token}/{filename}"

    def get_local_file(self, token: str) -> str | None:
        with self.lock:
            return self._local_files.get(token)

    def register_stream(self, url: str, headers: dict[str, str] | None = None) -> str:
        """Registra uma URL remota e headers retornando a URL de proxy http://127.0.0.1:<port>/stream/<token>."""
        token = secrets.token_urlsafe(16)
        with self.lock:
            self._streams[token] = {"url": url, "headers": headers or {}}
        return f"{self.base_url}/stream/{token}"

    def get_stream_info(self, token: str) -> dict[str, Any] | None:
        with self.lock:
            return self._streams.get(token)

