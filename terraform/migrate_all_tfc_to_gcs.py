#!/usr/bin/env python3
"""
One-shot: migrate OpenTofu state from Terraform Cloud to GCS for each terraform/* module.

OpenTofu cannot migrate automatically; this script uses state pull (while providers.tf
uses cloud {}) then state push (after restoring backend "gcs").

Requires:
  - TF_TOKEN_app_terraform_io
  - GCP ADC (e.g. gcloud auth application-default login) for the state bucket
  - gs://dominiksiejak-gitops-tfstate exists

Run from repo root: python3 terraform/migrate_all_tfc_to_gcs.py
"""

from __future__ import annotations

import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(ROOT)
ORG = 'dominiksiejak'
HOST = 'app.terraform.io'
BUCKET = 'dominiksiejak-gitops-tfstate'

CLOUD_BLOCK = """  cloud {{
    hostname     = "{host}"
    organization = "{org}"

    workspaces {{
      name = "{workspace}"
    }}
  }}"""


def workspace_for_dir(name: str) -> str:
    return f"gitops-{name}"


def backend_gcs_to_cloud(content: str, workspace: str) -> str:
    block = CLOUD_BLOCK.format(host=HOST, org=ORG, workspace=workspace)
    return re.sub(
        r"  backend \"gcs\" \{[\s\S]*?\n  \}",
        block,
        content,
        count=1,
    )


def cloud_to_backend_gcs(content: str, prefix: str) -> str:
    return re.sub(
        r'  cloud \{[\s\S]*?\n  \}',
        f'  backend "gcs" {{\n    bucket = "{BUCKET}"\n    prefix = "{prefix}"\n  }}',
        content,
        count=1,
    )


def extract_prefix(content: str) -> str | None:
    m = re.search(r'prefix\s*=\s*"([^"]+)"', content)
    return m.group(1) if m else None


def run(cmd: list[str], cwd: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, cwd=cwd, text=True, capture_output=True)


def main() -> int:
    if not os.environ.get('TF_TOKEN_app_terraform_io'):
        print('error: set TF_TOKEN_app_terraform_io', file=sys.stderr)
        return 1

    modules = sorted(
        d
        for d in os.listdir(ROOT)
        if os.path.isfile(os.path.join(ROOT, d, 'providers.tf'))
    )

    failed: list[str] = []

    for name in modules:
        path = os.path.join(ROOT, name, 'providers.tf')
        with open(path, encoding='utf-8') as f:
            original = f.read()

        ws = workspace_for_dir(name)
        prefix = extract_prefix(original) or ws
        tmp_state = f"/tmp/migrate-{name}.tfstate"

        print(f"\n=== {name} (workspace {ws}, prefix {prefix}) ===")

        # --- Pull from TFC ---
        if 'backend "gcs"' in original:
            cloud_content = backend_gcs_to_cloud(original, ws)
            if cloud_content == original:
                print('  skip: could not replace gcs backend (regex mismatch)')
                failed.append(name)
                continue
            with open(path, 'w', encoding='utf-8') as f:
                f.write(cloud_content)
        elif re.search(r'^\s*cloud\s*\{', original, re.MULTILINE):
            print('  pull: already using cloud {} backend')
        else:
            print('  skip: no gcs or cloud backend found')
            failed.append(name)
            continue

        mod_dir = os.path.join(ROOT, name)
        r = run(['rm', '-rf', '.terraform'], cwd=mod_dir)
        r = run(['tofu', 'init', '-input=false'], cwd=mod_dir)
        if r.returncode != 0:
            print(r.stdout)
            print(r.stderr, file=sys.stderr)
            with open(path, 'w', encoding='utf-8') as f:
                f.write(original)
            failed.append(name)
            continue

        r = run(['tofu', 'state', 'pull'], cwd=mod_dir)
        if r.returncode != 0:
            print(r.stderr, file=sys.stderr)
            with open(path, 'w', encoding='utf-8') as f:
                f.write(original)
            failed.append(name)
            continue

        with open(tmp_state, 'w', encoding='utf-8') as f:
            f.write(r.stdout)

        print(f"  pulled state -> {tmp_state}")

        # Restore gcs backend in providers.tf
        if 'backend "gcs"' in original:
            with open(path, 'w', encoding='utf-8') as f:
                f.write(original)
        else:
            # was cloud only (e.g. gcp): inject gcs
            new_content = cloud_to_backend_gcs(original, prefix)
            if new_content == original:
                print('  error: could not replace cloud with gcs')
                with open(path, 'w', encoding='utf-8') as f:
                    f.write(original)
                failed.append(name)
                continue
            with open(path, 'w', encoding='utf-8') as f:
                f.write(new_content)

        r = run(['rm', '-rf', '.terraform'], cwd=mod_dir)
        r = run(['tofu', 'init', '-input=false'], cwd=mod_dir)
        if r.returncode != 0:
            print(r.stdout)
            print(r.stderr, file=sys.stderr)
            with open(path, 'w', encoding='utf-8') as f:
                f.write(original)
            failed.append(name)
            continue

        r = run(['tofu', 'state', 'push', tmp_state], cwd=mod_dir)
        if r.returncode != 0:
            print('  state push failed, retrying with -force ...')
            r = run(['tofu', 'state', 'push', '-force', tmp_state], cwd=mod_dir)
        if r.returncode != 0:
            print(r.stdout)
            print(r.stderr, file=sys.stderr)
            with open(path, 'w', encoding='utf-8') as f:
                f.write(original)
            failed.append(name)
            continue

        print('  pushed to GCS ok')

        r = run(['tofu', 'plan', '-input=false'], cwd=mod_dir)
        if r.returncode != 0:
            print(r.stdout)
            print(r.stderr, file=sys.stderr)
        else:
            print('  tofu plan: exit 0')

    if failed:
        print(f"\nFailed modules: {failed}", file=sys.stderr)
        return 1
    print('\nDone.')
    return 0


if __name__ == '__main__':
    os.chdir(REPO_ROOT)
    sys.exit(main())
