#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
check_dir="$(mktemp -d "${TMPDIR:-/tmp}/tinylunch-domain.XXXXXX")"
trap 'rm -rf "$check_dir"' EXIT
swiftc -swift-version 6 TinyLunch/Meal.swift TinyLunch/MealEstimateMapping.swift TinyLunch/NutritionCatalog.swift scripts/DomainChecks.swift -o "$check_dir/domain-checks"
"$check_dir/domain-checks" TinyLunch/Resources/NutritionCatalog/usda-sr-2018-04-foundation-2026-10-29-v1/catalog.json
