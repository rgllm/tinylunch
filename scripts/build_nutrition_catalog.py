#!/usr/bin/env python3
"""Build a deterministic kcal-only resource from pinned official USDA archives."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import urllib.request
import zipfile

VERSION = "usda-sr-2018-04-foundation-2026-10-29-v1"
SOURCES = [
    dict(file="sr-legacy.zip", collection="SRLegacyFoods", dataType="SR Legacy", release="2018-04",
         url="https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_sr_legacy_food_json_2018-04.zip",
         sha256="0fe8ae486a2c8eb42cb96413f058deb51863a46c8fb8eeb4b1fb45006dd338ef"),
    dict(file="foundation.zip", collection="FoundationFoods", dataType="Foundation", release="2026-10-29",
         url="https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_foundation_food_json_2026-10-29.zip",
         sha256="dd414cc9f1a132626bad354ef6655972c78b44aff14f16114dc899708663c579"),
]
STATES = ("raw", "cooked", "grilled", "broiled", "roasted", "baked", "boiled", "steamed",
          "stewed", "fried", "breaded", "battered", "dried", "dehydrated", "canned", "smoked")


def energy(food):
    # Foundation's specific Atwater factor takes precedence over general factors.
    priority = (2048, 2047, 1008) if food["dataType"] == "Foundation" else (1008,)
    for nutrient_id in priority:
        values = [n.get("amount") for n in food.get("foodNutrients", [])
                  if n["nutrient"]["id"] == nutrient_id
                  and n["nutrient"]["unitName"].lower() == "kcal"]
        valid = [v for v in values if isinstance(v, (int, float)) and not isinstance(v, bool)
                 and math.isfinite(v) and 0 <= v <= 1000]
        if len(valid) == 1:
            return valid[0], nutrient_id
    return None


def convert(food, release):
    value = energy(food)
    if value is None:
        return None
    name = food["description"].strip()
    tokens = set(re.findall(r"[a-z]+", name.lower()))
    portions = []
    for p in food.get("foodPortions", []):
        grams = p.get("gramWeight")
        if isinstance(grams, (int, float)) and math.isfinite(grams) and 0 < grams <= 10000:
            portions.append(dict(grams=grams, description=p.get("portionDescription") or
                " ".join(str(v) for v in (p.get("amount", ""), p.get("modifier", "")) if v).strip()))
    return dict(id=f"fdc-{food['fdcId']}", name=name,
                preparation=", ".join(s for s in STATES if s in tokens) or "Not specified in source description",
                kcalPer100g=value[0], energyNutrientID=value[1], dataType=food["dataType"], release=release,
                sourceURL=f"https://fdc.nal.usda.gov/food-details/{food['fdcId']}/nutrients",
                portions=portions)


def build(cache, output, download):
    rows = []
    counts = {}
    for source in SOURCES:
        archive = cache / source["file"]
        if not archive.exists() and download:
            cache.mkdir(parents=True, exist_ok=True)
            urllib.request.urlretrieve(source["url"], archive)
        if hashlib.sha256(archive.read_bytes()).hexdigest() != source["sha256"]:
            raise ValueError(f"Checksum mismatch: {archive}")
        with zipfile.ZipFile(archive) as z:
            files = [n for n in z.namelist() if n.endswith(".json")]
            if len(files) != 1:
                raise ValueError("Expected one source JSON file")
            foods = json.loads(z.read(files[0]))[source["collection"]]
        selected = [convert(f, source["release"]) for f in foods if f["dataType"] == source["dataType"]]
        rows.extend(r for r in selected if r is not None)
        counts[source["dataType"]] = dict(source=len(foods), included=sum(r is not None for r in selected))
    rows.sort(key=lambda r: r["id"])
    if len({r["id"] for r in rows}) != len(rows):
        raise ValueError("Duplicate FDC identifiers")
    output.mkdir(parents=True, exist_ok=True)
    catalog = dict(schemaVersion=1, version=VERSION, records=rows)
    (output / "catalog.json").write_text(json.dumps(catalog, ensure_ascii=False, separators=(",", ":"), allow_nan=False) + "\n")
    manifest = dict(version=VERSION, sources=SOURCES, counts=counts,
                    catalogSHA256=hashlib.sha256((output / "catalog.json").read_bytes()).hexdigest())
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps(counts, sort_keys=True))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache", type=Path, default=Path(".build/nutrition-sources"))
    parser.add_argument("--output", type=Path, default=Path("TinyLunch/Resources/NutritionCatalog") / VERSION)
    parser.add_argument("--download", action="store_true", help="Download missing pinned archives at development time")
    args = parser.parse_args()
    build(args.cache, args.output, args.download)
