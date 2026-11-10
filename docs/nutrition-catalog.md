# Local nutrition catalog

TinyLunch recognizes food with Apple's on-device Foundation Model and searches a bundled USDA catalog for energy density. The catalog does not identify food in a photograph or measure portion weight. Food names, cooking methods, and grams still need review.

## Bundled data

The initial resource combines FoodData Central SR Legacy, April 2018, and Foundation Foods, October 29, 2026. It includes 7,793 SR Legacy records and 374 Foundation records with valid energy values. Fifty Foundation records have no usable energy and are excluded rather than assigned zero. The resource is about 3 MB.

The catalog contains identity, preparation words from the source description, kcal per 100 g, the energy nutrient ID, source release, source URL, and documented portion weights where present. It excludes other nutrients and the Branded, FNDDS, and Experimental data types. SR Legacy itself contains some historical brand-named descriptions.

USDA publishes FoodData Central under CC0 1.0. The bundle includes attribution and a manifest with source archive URLs, SHA-256 checksums, record counts, and the generated resource checksum.

- [Official downloads](https://fdc.nal.usda.gov/download-datasets/)
- [USDA licensing and attribution](https://fdc.nal.usda.gov/api-guide)
- [Foundation energy definitions](https://fdc.nal.usda.gov/Foundation_Foods_Documentation)

INSA PortFIR is not bundled. Redistribution requires permission that this project does not have. No other food dataset is bundled.

## Build the resource

Run this at development time from the repository root:

```sh
python3 scripts/build_nutrition_catalog.py --download
python3 scripts/test_nutrition_builder.py
scripts/test-domain.sh
```

The script downloads only missing pinned archives to `.build/nutrition-sources`. It checks their SHA-256 hashes before conversion. Omit `--download` to rebuild entirely from cached archives. It emits `catalog.json` and `manifest.json` under `TinyLunch/Resources/NutritionCatalog/usda-sr-2018-04-foundation-2026-10-29-v1/`.

SR Legacy uses energy nutrient 1008. Foundation prefers 2048, the Atwater specific factor, then 2047, the general factor, then legacy 1008. The converter selects one finite value in kcal, between 0 and 1,000 per 100 g. It never adds energy measures or substitutes kJ. True zero values remain valid. Preparation labels come from source words and do not infer cooking when the description omits it.

To update the catalog, pin new archive URLs and checksums, change the version in the builder and `NutritionCatalog.bundledVersion`, regenerate, and run the checks. Retain the attribution file. Update this document's counts and release details. Do not recalculate history.

## Local matching

`NutritionCatalog` loads and searches the JSON on its actor, away from the UI actor. Search normalizes English case, accents, punctuation, and a small set of common food plurals. All query words must occur in a candidate description. Preparation filtering separates raw and cooked foods and specific cooking methods. Results are limited to five choices.

Automatic matching requires exactly one record with the same normalized identity words and preparation state. A top-ranked result alone is insufficient. Duplicate exact descriptions stay ambiguous even if their energies agree. Unresolved recognition alternatives prevent automatic substitution. Negated or uncertain preparation notes prevent automatic substitution. Unexplained preparation words, including added ingredients such as butter, also prevent automatic substitution.

Review shows the suggested food and its plausible alternatives. Selecting an alternative replaces the same item after re-estimation or matching. It never adds another portion. The editor also searches bundled USDA foods and shows their descriptions, preparation, and kcal per 100 g. Selecting a catalog result and tapping Apply uses its source value without calling the model. Search and selection work while Apple Intelligence is unavailable.

A missing or ambiguous match retains a valid model energy estimate, labelled **Model estimate**. A failed catalog load also retains model estimates and explains the catalog failure in the search section. Missing energy remains unknown. A catalog-derived estimate is labelled **USDA catalog estimate**, with the FDC ID and catalog version. These are still meal estimates because food identity and grams may be wrong.

## Corrections and history

Gram-only corrections preserve energy density and provenance. Swift computes `grams * kcalPer100g / 100` and sums unrounded item values.

Food or preparation changes invalidate energy density, catalog ID, and catalog version together. The editor holds pending changes until a replacement catalog match or model response succeeds. A failed correction leaves the previous draft intact. Cancellation and request IDs reject obsolete completions.

Save copies the energy basis, kcal per 100 g, grams, preparation, catalog ID, catalog version, and recognition suggestions into the existing local snapshot. Legacy records default to model-estimated energy and empty recognition alternatives. History load never searches the catalog or invokes the model. Unknown items and incomplete subtotals remain intact.

Runtime lookup is entirely local. Download URLs in the resource document provenance; the app does not fetch them. No USDA API, remote nutrition service, INSA, or cloud model is called.

## Verification limits

The new prompt and local catalog do not establish measured recognition or calorie accuracy. Portuguese mixed dishes have limited USDA coverage. Visual portions remain assumptions. Physical-iPhone evaluation, including airplane mode, is still required.

See [verification for this change](verification-food-estimates.md) for actual checks and environment blockers.
