#!/usr/bin/env python3
"""Unit tests for scripts/render_phase_env.py (no live Phase)."""

import sys
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / 'scripts'))

import render_phase_env as rpe  # noqa: E402


class RenderPhaseEnv(unittest.TestCase):
    def test_skip_without_token(self):
        old = rpe.os.environ.pop('PHASE_SERVICE_TOKEN', None)
        try:
            self.assertEqual(
                rpe.main(['--dest', '/tmp/phase-env-test-unused', '--token-file', '/nonexistent']),
                0,
            )
        finally:
            if old is not None:
                rpe.os.environ['PHASE_SERVICE_TOKEN'] = old

    def test_writes_all_mapped_apps(self):
        dest = Path(self._test_dest())
        calls = []

        def exporter(app, env, host, token):
            calls.append((app, env, host, token))
            return f'APP={app}\nENV={env}\n'

        written = rpe.render(
            dest,
            REPO / 'scripts' / 'phase_env_map.yaml',
            'https://phase.example',
            'tok',
            exporter=exporter,
        )
        self.assertEqual(len(written), len(calls))
        self.assertTrue((dest / 'n8n' / 'n8n.env').read_text().startswith('APP=n8n'))
        self.assertFalse((dest / 'phase' / 'phase.env').exists())

    def test_fails_closed_on_export_error(self):
        dest = Path(self._test_dest()) / 'fail'

        def exporter(app, env, host, token):
            raise RuntimeError('boom')

        with self.assertRaises(RuntimeError):
            rpe.render(
                dest,
                REPO / 'scripts' / 'phase_env_map.yaml',
                'https://phase.example',
                'tok',
                exporter=exporter,
            )
        self.assertFalse(any(dest.rglob('*.env')))

    def _test_dest(self):
        import tempfile
        return tempfile.mkdtemp(prefix='phase-env-')


if __name__ == '__main__':
    unittest.main()
