#!/usr/bin/env python3
"""
CLI for the Jimaku API (https://jimaku.cc/api/docs).

Two modes:
  - Interactive (no --json flag): prompts for a search query, lets you pick
    an entry, optionally filter by episode, and download a file.
  - Non-interactive (--json flag): fully driven by arguments, prints JSON,
    never prompts. Used by the jimaku-search skill.

API key resolution order:
  1. JIMAKU_API_KEY environment variable
  2. ~/.config/jimaku/api_key file
  3. Interactive prompt (only in interactive mode)

Interactive downloads default to a temp dir (/tmp/jimaku-subs) rather than
the current directory, since /tmp is tmpfs (cleared on reboot) and also
auto-purged by systemd-tmpfiles after 10 days -- so files don't pile up.
Override with --output-dir to save somewhere permanent.
"""

import argparse
import json
import os
import sys
import tempfile
from getpass import getpass
from pathlib import Path

import requests

BASE_URL = "https://jimaku.cc/api"
KEY_FILE = Path.home() / ".config" / "jimaku" / "api_key"
DEFAULT_DOWNLOAD_DIR = Path(tempfile.gettempdir()) / "jimaku-subs"


def get_api_key(interactive: bool) -> str:
    key = os.environ.get("JIMAKU_API_KEY")
    if not key and KEY_FILE.exists():
        key = KEY_FILE.read_text().strip()
    if not key:
        if not interactive:
            sys.exit(
                f"No API key found. Set JIMAKU_API_KEY or save one to {KEY_FILE} "
                "(get a key at https://jimaku.cc/account)."
            )
        key = getpass("Enter your Jimaku API key: ").strip()
    if not key:
        sys.exit("An API key is required. Get one at https://jimaku.cc/account")
    return key


def api_get(path: str, headers: dict, params: dict | None = None):
    resp = requests.get(f"{BASE_URL}{path}", headers=headers, params=params)
    if resp.status_code == 429:
        reset_after = resp.headers.get("x-ratelimit-reset-after", "?")
        sys.exit(f"Rate limited. Try again in {reset_after}s.")
    if not resp.ok:
        try:
            err = resp.json()
            sys.exit(f"API error {resp.status_code}: {err.get('error')}")
        except ValueError:
            sys.exit(f"API error {resp.status_code}: {resp.text}")
    return resp.json()


def search_entries(query: str, headers: dict) -> list[dict]:
    return api_get("/entries/search", headers, params={"query": query})


def get_entry_files(entry_id: int, headers: dict, episode: int | None) -> list[dict]:
    params = {"episode": episode} if episode is not None else None
    return api_get(f"/entries/{entry_id}/files", headers, params=params)


def choose_entry(entries: list[dict]) -> dict:
    print(f"\nFound {len(entries)} result(s):\n")
    for i, e in enumerate(entries):
        name = e["name"]
        english = f" ({e['english_name']})" if e.get("english_name") else ""
        print(f"  [{i}] {name}{english}  -- id={e['id']}")
    while True:
        choice = input("\nSelect an entry number: ").strip()
        if choice.isdigit() and 0 <= int(choice) < len(entries):
            return entries[int(choice)]
        print("Invalid selection, try again.")


def human_size(num: int) -> str:
    for unit in ("B", "KB", "MB", "GB"):
        if num < 1024:
            return f"{num:.1f}{unit}"
        num /= 1024
    return f"{num:.1f}TB"


def run_json_mode(args, headers: dict):
    if args.entry_id is not None:
        files = get_entry_files(args.entry_id, headers, args.episode)
        print(json.dumps(files, indent=2))
    else:
        if not args.query:
            sys.exit("--json mode requires a query or --entry-id")
        entries = search_entries(args.query, headers)
        print(json.dumps(entries, indent=2))


def run_interactive_mode(args, headers: dict):
    query = args.query or input("Search for an anime/show: ").strip()
    if not query:
        sys.exit("No search query given.")

    entries = search_entries(query, headers)
    if not entries:
        sys.exit("No entries found.")

    entry = choose_entry(entries)

    if args.episode is not None:
        episode = args.episode
    else:
        ep_input = input(
            "\nEpisode number to filter by (leave blank for all files): "
        ).strip()
        episode = int(ep_input) if ep_input.isdigit() else None

    files = get_entry_files(entry["id"], headers, episode)
    if not files:
        print("No files found for that entry/episode.")
        return

    print(f"\nFiles for '{entry['name']}'"
          f"{f' (episode {episode})' if episode is not None else ''}:\n")
    for i, f in enumerate(files):
        print(f"  [{i}] {f['name']}  ({human_size(f['size'])})")

    choice = input(
        "\nEnter a number to download that file, or press Enter to exit: "
    ).strip()
    if choice.isdigit() and 0 <= int(choice) < len(files):
        target = files[int(choice)]
        print(f"Downloading {target['name']} ...")
        r = requests.get(target["url"])
        r.raise_for_status()
        out_dir = args.output_dir or DEFAULT_DOWNLOAD_DIR
        out_dir.mkdir(parents=True, exist_ok=True)
        out_path = out_dir / target["name"]
        out_path.write_bytes(r.content)
        print(f"Saved to {out_path}")


def main():
    parser = argparse.ArgumentParser(description="Search Jimaku and list/download subtitle files.")
    parser.add_argument("query", nargs="?", help="Show name to search for")
    parser.add_argument("--episode", "-e", type=int, help="Filter files by episode number")
    parser.add_argument("--entry-id", type=int, help="Skip search, list files for this entry ID directly")
    parser.add_argument("--json", action="store_true", help="Non-interactive: print JSON and exit")
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=None,
        help=f"Directory to save downloads to (interactive mode only). Default: {DEFAULT_DOWNLOAD_DIR}",
    )
    args = parser.parse_args()

    headers = {"Authorization": get_api_key(interactive=not args.json)}

    if args.json:
        run_json_mode(args, headers)
    else:
        run_interactive_mode(args, headers)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit("\nAborted.")
