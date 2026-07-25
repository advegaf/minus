#!/usr/bin/env python3
"""Turns scripts/catalog-apps.tsv into the compiled-in catalog.

Every row needs a bundle identifier, because identity is how minus launches.
Pinned ids (Apple's own apps, the user's own builds) are taken as given; the
rest are resolved once against Apple's iTunes Search endpoint and cached in
catalog-cache.json, so a rebuild is deterministic, offline, and does not
re-hammer an API that rate-limits at around forty calls in a row.

The resolution log is the point. A wrong-but-valid identifier is invisible at
runtime — the private launch call reports nothing — so every match is printed
as `typed name -> store name (id)` for a human to read. That is what catches
"Aura" quietly resolving to Aura Frames.

Usage:
    python3 scripts/build_catalog.py            # resolve new rows, emit Swift
    python3 scripts/build_catalog.py --check    # resolve only, emit nothing
"""
import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request

ROOT = os.path.join(os.path.dirname(__file__), "..")
SOURCE = os.path.join(ROOT, "scripts/catalog-apps.tsv")
CACHE = os.path.join(ROOT, "scripts/catalog-cache.json")
OUT = os.path.join(ROOT, "Minus/Data/EssentialAppCatalog+Generated.swift")

# Swift's type checker is superlinear on big array literals, so the catalog is
# emitted as chunks that are concatenated at load.
CHUNK = 40


def slugify(name):
    """"Cash App" -> "cashapp"; "1.1.1.1" -> "1111". Stable, since a slug is
    what a card stores and what a widget publishes."""
    return re.sub(r"[^a-z0-9]", "", name.lower())


def normalize(text):
    return re.sub(r"[^a-z0-9]", "", (text or "").lower())


def read_source():
    rows = []
    for line in open(SOURCE, encoding="utf-8"):
        line = line.rstrip("\n")
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        parts = line.split("\t")
        name = parts[0].strip()
        category = parts[1].strip() if len(parts) > 1 else "tools"
        pinned = parts[2].strip() if len(parts) > 2 and parts[2].strip() else None
        rows.append({"name": name, "category": category, "bundleID": pinned})
    return rows


def search(term, limit=12):
    query = urllib.parse.urlencode(
        {"term": term, "entity": "software", "country": "us", "limit": limit}
    )
    with urllib.request.urlopen("https://itunes.apple.com/search?" + query, timeout=25) as response:
        return json.load(response).get("results", [])


def pick(name, results):
    """The store's title is usually the app's name plus a tagline, so an exact
    match is rare and a prefix match misses whole classes ("Rec Sports" ships as
    "Texas A&M Rec Sports"). Score instead: exact, then prefix, then either
    string contained in the other."""
    target = normalize(name)
    best = None
    for row in results:
        title = normalize(row.get("trackName"))
        if not title or not row.get("bundleId"):
            continue
        if title == target:
            score = 0
        elif title.startswith(target):
            score = 1
        elif target in title:
            score = 2
        elif title in target:
            score = 3
        else:
            continue
        if best is None or score < best[0]:
            best = (score, row)
    return best[1] if best else None


def main():
    check_only = "--check" in sys.argv
    rows = read_source()
    cache = json.load(open(CACHE)) if os.path.exists(CACHE) else {}

    resolved, unresolved = [], []
    for row in rows:
        name = row["name"]
        if row["bundleID"]:
            resolved.append({**row, "storeName": "(pinned)"})
            continue
        if name in cache:
            resolved.append({**row, **cache[name]})
            continue

        match = None
        for attempt in range(4):
            try:
                match = pick(name, search(name))
                break
            except Exception:
                time.sleep(6)  # rate limited; the endpoint recovers quickly
        if match:
            entry = {"bundleID": match["bundleId"], "storeName": match.get("trackName", "")}
            cache[name] = entry
            resolved.append({**row, **entry})
            print(f"  {name:24s} -> {entry['storeName'][:44]:46s} {entry['bundleID']}")
        else:
            unresolved.append(name)
            print(f"  {name:24s} -> NOTHING FOUND")
        time.sleep(1.1)

    json.dump(cache, open(CACHE, "w"), indent=1, sort_keys=True)

    if unresolved:
        print(f"\nunresolved ({len(unresolved)}): {', '.join(unresolved)}")
        print("pin these by hand in catalog-apps.tsv, or drop them.")

    # A duplicate slug would collapse the ForEach that renders the picker.
    seen, unique = set(), []
    for row in resolved:
        slug = slugify(row["name"])
        if slug in seen:
            print(f"  DUPLICATE SLUG dropped: {row['name']} ({slug})")
            continue
        seen.add(slug)
        unique.append({**row, "slug": slug})

    if check_only:
        print(f"\n{len(unique)} rows would be written; {len(unresolved)} unresolved.")
        return

    chunks = [unique[i:i + CHUNK] for i in range(0, len(unique), CHUNK)]
    lines = [
        "// GENERATED by scripts/build_catalog.py from scripts/catalog-apps.tsv.",
        "// Do not edit by hand: add a row to the TSV and regenerate.",
        "//",
        "// Every identifier here is either pinned (Apple's own apps, which are",
        "// not in the store, and builds belonging to the user) or resolved once",
        "// against the App Store and cached. Identity is the launch route, so a",
        "// row without one could never open anything and is never emitted.",
        "",
        "extension EssentialAppCatalog {",
    ]
    for index, chunk in enumerate(chunks):
        lines.append(f"    static let generated{index}: [CatalogApp] = [")
        for row in chunk:
            name = row["name"].replace('"', '\\"')
            lines.append(
                f'        CatalogApp(slug: "{row["slug"]}", displayName: "{name}", '
                f'category: .{row["category"]}, bundleID: "{row["bundleID"]}"),'
            )
        lines.append("    ]")
        lines.append("")
    joined = " + ".join(f"generated{i}" for i in range(len(chunks)))
    lines.append(f"    static let generatedAll: [CatalogApp] = {joined}")
    lines.append("}")
    open(OUT, "w").write("\n".join(lines) + "\n")
    print(f"\nwrote {OUT}: {len(unique)} apps in {len(chunks)} chunks")


main()
