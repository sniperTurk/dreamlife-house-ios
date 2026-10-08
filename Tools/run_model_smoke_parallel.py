#!/usr/bin/env python3
"""Fast, isolated Linux Swift model regression runner (not Apple XCTest)."""
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
import os
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
MODEL = ROOT / 'DreamLifeHouse/Models/GameStore.swift'
VERSIONS = range(233, 256)


def execute(version: int, temporary: Path):
    source = ROOT / f'Tools/ModelSmokeV{version}.swift'
    binary = temporary / f'dreamlife-v{version}'
    if not source.exists():
        raise RuntimeError(f'v{version}: missing test source {source}')
    compile_result = subprocess.run(
        ['swiftc', '-D', 'DEBUG', '-parse-as-library', str(MODEL),
         str(source), '-o', str(binary)],
        capture_output=True, text=True, timeout=120,
    )
    if compile_result.returncode:
        raise RuntimeError(f'v{version}: Swift compilation failed:\n{compile_result.stderr}')
    env = os.environ.copy()
    if version == 247:
        env['DREAMLIFE_TEST_ARCHIVE_PATH'] = str(temporary / 'recovery-v2.json')
    result = subprocess.run([str(binary)], capture_output=True, text=True,
                            env=env, timeout=60)
    if result.returncode:
        raise RuntimeError(f'v{version}: smoke execution failed:\n{result.stdout}\n{result.stderr}')
    match = re.search(r'(\d+)/(\d+) assertions PASSED', result.stdout)
    if not match or int(match[1]) != int(match[2]) or int(match[1]) == 0:
        raise RuntimeError(f'v{version}: missing successful assertion count:\n{result.stdout}')
    return version, int(match[1]), result.stdout.strip()


def main() -> int:
    with tempfile.TemporaryDirectory(prefix='dreamlife-smoke-') as folder:
        temporary = Path(folder)
        results = {}
        errors = []
        with ThreadPoolExecutor(max_workers=3) as executor:
            jobs = {executor.submit(execute, v, temporary): v for v in VERSIONS}
            for future in as_completed(jobs):
                version = jobs[future]
                try:
                    v, count, message = future.result()
                    results[v] = count
                    print(message, flush=True)
                except Exception as exc:
                    errors.append(f'v{version}: {exc}')
        if errors:
            print('\n'.join(errors), file=sys.stderr)
            return 1
        total = sum(results.values())
        print(f'All {len(results)} isolated Swift model suites: {total}/{total} assertions PASSED')
        for cmd in [
            [sys.executable, str(ROOT / 'Tools/verify_recovery_archive.py'),
             str(temporary / 'recovery-v2.json')],
            [sys.executable, '-m', 'unittest', 'discover', '-s',
             str(ROOT / 'Tools'), '-p', 'test_recovery_archive_verifier.py', '-v'],
            [sys.executable, str(ROOT / 'Tools/check_house_wiring.py')],
        ]:
            completed = subprocess.run(cmd, text=True)
            if completed.returncode:
                return completed.returncode
        return 0


if __name__ == '__main__':
    sys.exit(main())
