#!/usr/bin/env python3
"""Sequential original acquisition; run with python3 -I download.py SOUND_ID.
Private OAuth JSON is read at runtime. No credential or signed URL is logged.
Shared batch ledger counts redirects; blocked/HTML responses stop the batch.
"""
from datetime import date
import fcntl
import hashlib
import json
from pathlib import Path
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

WORK = Path.home() / 'FirehawkAudioWork'
BATCH = WORK / 'freesound-approved-2026-10-27'
BATCH.mkdir(parents=True, exist_ok=True)
ALLOWED = {
    'creativecommons.org/publicdomain/zero/1.0': 'CC0-1.0',
    'creativecommons.org/licenses/by/3.0': 'CC-BY-3.0',
    'creativecommons.org/licenses/by/4.0': 'CC-BY-4.0',
}

def is_audio(data):
    return ((data[:4] == b'RIFF' and data[8:12] == b'WAVE')
            or data.startswith((b'fLaC', b'OggS', b'ID3'))
            or (data[:4] == b'FORM' and data[8:12] in (b'AIFF', b'AIFC'))
            or (len(data) >= 4 and data[0] == 0xff
                and data[1] & 0xe0 == 0xe0 and data[1] & 0x18 != 0x08
                and data[1] & 0x06 != 0 and data[2] & 0xf0 not in (0, 0xf0)
                and data[2] & 0x0c != 0x0c))

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args):
        return None

def main():
    sound_id = int(sys.argv[1])
    private = Path(sys.argv[2]).expanduser() if len(sys.argv) > 2 else Path.home() / '.config/firehawk/freesound-oauth.json'
    token = json.loads(private.read_text())['access_token']
    root = WORK / 'raw/freesound' / str(sound_id)
    root.mkdir(parents=True, exist_ok=True)
    state_path = BATCH / 'state.json'
    state = json.loads(state_path.read_text()) if state_path.exists() else {'requests': 0, 'lastStart': 0, 'stopped': False}
    if state['stopped']:
        raise SystemExit('Acquisition stopped by an earlier blocked response')
    if (root / 'original.audio').exists():
        raise SystemExit('Original exists; refusing another download')

    def save():
        state_path.write_text(json.dumps(state, indent=2) + '\n')

    def stop(reason):
        state.update(stopped=True, reason=reason)
        save()
        raise SystemExit(reason)

    opener = urllib.request.build_opener(NoRedirect)
    def fetch(url, kind, destination):
        for _ in range(5):
            parsed = urllib.parse.urlparse(url)
            host = parsed.hostname or ''
            if parsed.scheme != 'https' or host not in ('freesound.org', 'cdn.freesound.org') or parsed.port not in (None, 443) or parsed.username or parsed.password:
                stop('Unexpected download host or insecure redirect')
            if state['requests'] >= 30:
                raise SystemExit('30-request budget exhausted')
            time.sleep(max(0, 3.2 - (time.time() - state['lastStart'])))
            state.update(requests=state['requests'] + 1, lastStart=time.time())
            save()
            headers = {'User-Agent': 'FirehawkFocus/1.0 original acquisition'}
            if host == 'freesound.org':
                headers['Authorization'] = 'Bearer ' + token
            try:
                response = opener.open(urllib.request.Request(url, headers=headers), timeout=180)
            except urllib.error.HTTPError as error:
                response = error
            status = response.code
            with (BATCH / 'requests.jsonl').open('a') as ledger:
                ledger.write(json.dumps(dict(number=state['requests'], time=state['lastStart'], soundID=sound_id, kind=kind, status=status)) + '\n')
            if status in (403, 429):
                response.close()
                stop('Freesound blocked response HTTP ' + str(status))
            if status in (301, 302, 303, 307, 308):
                target = urllib.parse.urlparse(urllib.parse.urljoin(url, response.headers.get('Location', '')))
                response.close()
                if (kind != 'original' or host != 'freesound.org' or status not in (301, 302)
                        or target.scheme != 'https' or target.hostname != 'cdn.freesound.org'
                        or target.port not in (None, 443) or target.username or target.password):
                    stop('Unexpected redirect; only HTTPS cdn.freesound.org download redirects allowed')
                url = target.geturl()
                continue
            if 'html' in response.headers.get('Content-Type', '').lower():
                response.close()
                stop('HTML response; no further Freesound requests permitted')
            if status != 200:
                response.close()
                raise SystemExit('Freesound HTTP ' + str(status) + '; no automatic retry')
            expected = response.headers.get('Content-Length')
            digest, size = hashlib.sha256(), 0
            partial = destination.with_suffix('.partial')
            try:
                with response, partial.open('wb') as output:
                    first = response.read(4096)
                    sniff = first.lstrip().lower()
                    if sniff.startswith((b'<!doctype html', b'<html')) or b'captcha' in sniff:
                        stop('HTML/captcha response; no further Freesound requests permitted')
                    if kind == 'original' and not is_audio(first):
                        stop('Original response has no recognized audio signature')
                    output.write(first)
                    digest.update(first)
                    size += len(first)
                    while chunk := response.read(1024 * 1024):
                        output.write(chunk)
                        digest.update(chunk)
                        size += len(chunk)
                if expected and size != int(expected):
                    raise SystemExit('Incomplete response; no automatic retry')
                partial.replace(destination)
                return digest.hexdigest(), size
            finally:
                partial.unlink(missing_ok=True)
        raise SystemExit('Redirect limit exceeded')

    fetch(f'https://freesound.org/apiv2/sounds/{sound_id}/', 'metadata', root / 'metadata.json')
    metadata = json.loads((root / 'metadata.json').read_text())
    license_url = urllib.parse.urlparse(metadata['license'])
    license_key = license_url.netloc + license_url.path.rstrip('/')
    if license_key not in ALLOWED:
        raise SystemExit('Licence outside allowed set; original not downloaded')
    digest, size = fetch(f'https://freesound.org/apiv2/sounds/{sound_id}/download/', 'original', root / 'original.audio')
    metadata.update(downloadSHA256=digest, downloadDate=date.today().isoformat(), verifiedLicense=ALLOWED[license_key])
    (root / 'metadata.json').write_text(json.dumps(metadata, indent=2) + '\n')
    print(f'Downloaded {sound_id}: {size} bytes; licence {metadata["verifiedLicense"]}; batch requests {state["requests"]}', flush=True)

if __name__ == '__main__':
    with (BATCH / 'lock').open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            main()
        except (urllib.error.URLError, TimeoutError, OSError, ValueError, KeyError) as error:
            raise SystemExit('Acquisition failed (' + type(error).__name__ + '); no automatic retry') from None
