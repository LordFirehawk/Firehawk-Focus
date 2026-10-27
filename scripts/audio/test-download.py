"""Offline acquisition regression checks. Run with python3 -I scripts/audio/test-download.py."""
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('download', Path(__file__).with_name('download.py'))
download = importlib.util.module_from_spec(spec)
spec.loader.exec_module(download)

class Response(io.BytesIO):
    def __init__(self, code, body=b'', **headers):
        super().__init__(body)
        self.code = code
        self.headers = headers

class AcquisitionTests(unittest.TestCase):
    def run_download(self, redirect, body=b'RIFF\x00\x00\x00\x00WAVEdata', final_headers=None):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            batch = root / 'batch'
            batch.mkdir()
            private = root / 'private.json'
            private.write_text(json.dumps({'access_token': 'offline-test-only'}))
            responses = [Response(200, json.dumps({'license': 'https://creativecommons.org/publicdomain/zero/1.0/'}).encode()), redirect,
                         Response(200, body, **(final_headers or {}))]
            seen = []
            class Opener:
                def open(self, request, timeout):
                    seen.append(request)
                    return responses.pop(0)
            with patch.object(download, 'WORK', root), patch.object(download, 'BATCH', batch), \
                 patch.object(download.sys, 'argv', ['download.py', '123', str(private)]), \
                 patch.object(download.urllib.request, 'build_opener', return_value=Opener()), \
                 patch.object(download.time, 'sleep'):
                try:
                    download.main()
                    failure = None
                except SystemExit as error:
                    failure = str(error)
            original = root / 'raw/freesound/123/original.audio'
            partial = original.with_suffix('.partial')
            return failure, seen, original.exists(), partial.exists()

    def test_expected_html_redirect_and_unsigned_cdn_request(self):
        for status in (301, 302):
            with self.subTest(status=status):
                failure, seen, exists, _ = self.run_download(Response(status, b'<html>redirect</html>', **{
                    'Content-Type': 'text/html', 'Location': 'https://cdn.freesound.org/sounds/test.wav' + '?test=offline'}))
                self.assertIsNone(failure)
                self.assertTrue(exists)
                self.assertEqual(len(seen), 3)
                self.assertIsNotNone(seen[1].get_header('Authorization'))
                self.assertIsNone(seen[2].get_header('Authorization'))

    def test_unsafe_redirects_stop_before_next_request(self):
        for location in ('https://evil.example/test.wav', 'http://cdn.freesound.org/test.wav',
                         'https://cdn.freesound.org.evil.example/test.wav', 'https://freesound.org/test.wav',
                         'https://cdn.freesound.org:8443/test.wav', 'https://user@cdn.freesound.org/test.wav'):
            with self.subTest(location=location):
                failure, seen, exists, _ = self.run_download(Response(302, **{'Location': location}))
                self.assertIn('Unexpected redirect', failure)
                self.assertEqual(len(seen), 2)
                self.assertFalse(exists)

    def test_blocked_and_non_audio_bodies_are_not_kept(self):
        for response in (Response(403), Response(429), Response(200, b'<html>captcha</html>')):
            failure, seen, exists, partial = self.run_download(response)
            self.assertIsNotNone(failure)
            self.assertEqual(len(seen), 2)
            self.assertFalse(exists)
            self.assertFalse(partial)
        for body in (b'not audio', b'<html>captcha</html>'):
            failure, _, exists, partial = self.run_download(Response(302, **{'Location': 'https://cdn.freesound.org/test.wav'}), body)
            self.assertIsNotNone(failure)
            self.assertFalse(exists)
            self.assertFalse(partial)

    def test_incomplete_body_is_not_kept(self):
        failure, _, exists, partial = self.run_download(
            Response(302, **{'Location': 'https://cdn.freesound.org/test.wav'}),
            final_headers={'Content-Length': '1000'})
        self.assertIn('Incomplete response', failure)
        self.assertFalse(exists)
        self.assertFalse(partial)

    def test_audio_signatures(self):
        for body in (b'RIFF1234WAVE', b'FORM1234AIFF', b'FORM1234AIFC', b'fLaC', b'OggS', b'ID3', b'\xff\xfb\x90\x00'):
            self.assertTrue(download.is_audio(body), body)
        for body in (b'', b'RIFF1234AVI ', b'FORM1234HTML', b'\xff\xff\xff\xff', b'<html>'):
            self.assertFalse(download.is_audio(body), body)

if __name__ == '__main__':
    unittest.main()
