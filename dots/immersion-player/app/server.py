#!/usr/bin/env python3
"""
immersion-player: a local video player that generates Japanese subtitles with
Whisper and renders them as page text, so Yomitan hover lookups and mining
work on them exactly like on any web page.

  immersion-player --media ~/Videos/anime     # then open http://127.0.0.1:8765

Subtitles are generated on the GPU (faster-whisper) the first time a file is
opened, streamed to the player while transcription runs, and cached in
~/.cache/immersion-player so rewatches are instant. Sidecar .srt/.vtt files
next to a video show up as alternative tracks.
"""
import argparse
import hashlib
import json
import mimetypes
import os
import queue
import re
import sys
import threading
import traceback
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, unquote, urlparse

VIDEO_EXTS = {'.mp4', '.mkv', '.webm', '.m4v', '.mov'}
SUB_EXTS = {'.srt', '.vtt'}
STATIC_DIR = Path(__file__).resolve().parent / 'static'
CACHE_DIR = Path(os.environ.get('XDG_CACHE_HOME') or Path.home() / '.cache') / 'immersion-player'

# Chrome plays Matroska fine but refuses it when labelled video/x-matroska.
mimetypes.add_type('video/webm', '.mkv')
mimetypes.add_type('text/vtt', '.vtt')


def safe_join(root, rel):
    path = (root / rel).resolve()
    return path if path.is_relative_to(root) else None


class Transcriber:
    def __init__(self, args):
        self.args = args
        self.model = None
        self.jobs = {}
        self.lock = threading.Lock()
        self.queue = queue.Queue()
        threading.Thread(target=self._worker, daemon=True).start()

    def _key(self, path):
        st = path.stat()
        raw = f'{path}|{st.st_size}|{st.st_mtime_ns}|{self.args.model}|{self.args.language}'
        return hashlib.sha1(raw.encode()).hexdigest()

    def _cache_path(self, key):
        return CACHE_DIR / f'{key}.json'

    def is_cached(self, path):
        return self._cache_path(self._key(path)).exists()

    def status(self, path, start=False):
        key = self._key(path)
        cached = self._cache_path(key)
        if cached.exists():
            return {'status': 'done', 'progress': 1.0, 'segments': json.loads(cached.read_text())}
        with self.lock:
            job = self.jobs.get(key)
            if start and (job is None or job['status'] == 'error'):
                job = self.jobs[key] = {'status': 'queued', 'progress': 0.0, 'segments': [], 'error': None}
                self.queue.put((key, path))
            if job is None:
                return {'status': 'none'}
            return {**job, 'segments': list(job['segments'])}

    def _load_model(self):
        if self.model is None:
            from faster_whisper import WhisperModel
            print(f'loading {self.args.model} on {self.args.device}...', file=sys.stderr)
            self.model = WhisperModel(self.args.model, device=self.args.device,
                                      compute_type=self.args.compute_type)
        return self.model

    def _worker(self):
        while True:
            key, path = self.queue.get()
            job = self.jobs[key]
            try:
                with self.lock:
                    job['status'] = 'loading-model' if self.model is None else 'running'
                model = self._load_model()
                with self.lock:
                    job['status'] = 'running'
                segments, info = model.transcribe(
                    str(path),
                    language=self.args.language,
                    beam_size=5,
                    vad_filter=True,
                    # Carrying context between windows is what makes Whisper
                    # loop the same line over music and silence.
                    condition_on_previous_text=False,
                )
                for seg in segments:
                    text = seg.text.strip()
                    with self.lock:
                        if text:
                            job['segments'].append({'start': round(seg.start, 3),
                                                    'end': round(seg.end, 3), 'text': text})
                        if info.duration:
                            job['progress'] = min(seg.end / info.duration, 1.0)
                CACHE_DIR.mkdir(parents=True, exist_ok=True)
                tmp = self._cache_path(key).with_suffix('.tmp')
                tmp.write_text(json.dumps(job['segments'], ensure_ascii=False))
                os.replace(tmp, self._cache_path(key))
                with self.lock:
                    del self.jobs[key]
                print(f'transcribed {path.name}: {len(job["segments"])} lines', file=sys.stderr)
            except Exception as e:
                traceback.print_exc()
                with self.lock:
                    job['status'] = 'error'
                    job['error'] = f'{type(e).__name__}: {e}'


def list_files(root, transcriber):
    files = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = sorted(d for d in dirnames if not d.startswith('.'))
        here = Path(dirpath)
        for name in sorted(filenames):
            path = here / name
            if path.suffix.lower() not in VIDEO_EXTS:
                continue
            subs = [(here / n).relative_to(root).as_posix() for n in sorted(filenames)
                    if Path(n).suffix.lower() in SUB_EXTS and n.startswith(path.stem)]
            files.append({'path': path.relative_to(root).as_posix(), 'subs': subs,
                          'cached': transcriber.is_cached(path)})
    return files


def make_handler(media_root, transcriber, allowed_hosts):
    class Handler(BaseHTTPRequestHandler):
        server_version = 'immersion-player'

        def log_message(self, fmt, *args):
            pass

        def _host_ok(self):
            # Blocks DNS rebinding: other sites resolving to 127.0.0.1 can't read your media.
            if allowed_hosts is None:
                return True
            host = (self.headers.get('Host') or '').rsplit(':', 1)[0]
            if host in allowed_hosts:
                return True
            self._send_error(403)
            return False

        def _send_error(self, code, msg=''):
            body = msg.encode()
            self.send_response(code)
            self.send_header('Content-Type', 'text/plain; charset=utf-8')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def _json(self, data):
            body = json.dumps(data, ensure_ascii=False).encode()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Content-Length', str(len(body)))
            self.send_header('Cache-Control', 'no-store')
            self.end_headers()
            self.wfile.write(body)

        def _file(self, path):
            if path is None or not path.is_file():
                return self._send_error(404)
            size = path.stat().st_size
            start, end = 0, size - 1
            m = re.fullmatch(r'bytes=(\d*)-(\d*)', self.headers.get('Range') or '')
            if m and (m[1] or m[2]):
                if m[1]:
                    start = int(m[1])
                    end = min(int(m[2]), size - 1) if m[2] else size - 1
                else:
                    start = max(size - int(m[2]), 0)
                if start > end:
                    self.send_response(416)
                    self.send_header('Content-Range', f'bytes */{size}')
                    self.end_headers()
                    return
                self.send_response(206)
                self.send_header('Content-Range', f'bytes {start}-{end}/{size}')
            else:
                self.send_response(200)
            self.send_header('Content-Type', mimetypes.guess_type(path.name)[0] or 'application/octet-stream')
            self.send_header('Accept-Ranges', 'bytes')
            self.send_header('Content-Length', str(end - start + 1))
            self.end_headers()
            with open(path, 'rb') as f:
                f.seek(start)
                remaining = end - start + 1
                while remaining > 0:
                    chunk = f.read(min(1 << 20, remaining))
                    if not chunk:
                        break
                    try:
                        self.wfile.write(chunk)
                    except (BrokenPipeError, ConnectionResetError):
                        return
                    remaining -= len(chunk)

        def _media_path(self, query):
            rel = parse_qs(query).get('path', [''])[0]
            path = safe_join(media_root, rel) if rel else None
            return path if path and path.is_file() and path.suffix.lower() in VIDEO_EXTS else None

        def do_GET(self):
            if not self._host_ok():
                return
            url = urlparse(self.path)
            p = unquote(url.path)
            if p == '/':
                return self._file(STATIC_DIR / 'index.html')
            if p.startswith('/static/'):
                return self._file(safe_join(STATIC_DIR, p[len('/static/'):]))
            if p.startswith('/media/'):
                return self._file(safe_join(media_root, p[len('/media/'):]))
            if p == '/api/files':
                return self._json(list_files(media_root, transcriber))
            if p == '/api/subs':
                path = self._media_path(url.query)
                return self._json(transcriber.status(path)) if path else self._send_error(404)
            self._send_error(404)

        def do_POST(self):
            if not self._host_ok():
                return
            url = urlparse(self.path)
            # Requiring JSON forces a CORS preflight, so other sites can't start jobs.
            if not (self.headers.get('Content-Type') or '').startswith('application/json'):
                return self._send_error(415)
            if url.path == '/api/transcribe':
                path = self._media_path(url.query)
                return self._json(transcriber.status(path, start=True)) if path else self._send_error(404)
            self._send_error(404)

    return Handler


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--media', type=Path, default=Path(os.environ.get('IMMERSION_MEDIA', Path.home() / 'Videos')),
                    help='folder to browse for videos (default: $IMMERSION_MEDIA or ~/Videos)')
    ap.add_argument('--host', default='127.0.0.1')
    ap.add_argument('--port', type=int, default=8765)
    ap.add_argument('--model', default='large-v3',
                    help='faster-whisper model name or path (e.g. large-v3-turbo for speed)')
    ap.add_argument('--language', default='ja')
    ap.add_argument('--device', default='cuda', help='cuda or cpu')
    ap.add_argument('--compute-type', default='auto')
    args = ap.parse_args()

    media_root = args.media.expanduser().resolve()
    if not media_root.is_dir():
        sys.exit(f'media folder not found: {media_root}')
    allowed_hosts = None if args.host in ('0.0.0.0', '::') else {'localhost', '127.0.0.1', '[::1]', args.host}

    transcriber = Transcriber(args)
    server = ThreadingHTTPServer((args.host, args.port), make_handler(media_root, transcriber, allowed_hosts))
    print(f'immersion-player: http://{args.host}:{args.port}  (media: {media_root})', file=sys.stderr)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == '__main__':
    main()
