# Local nutrition catalog

Status: exploration, not scheduled implementation. The on-device model remains the energy source until photo analysis is measured on a physical iPhone.

## Verdict

A bundled catalog is **worth building after** live photo analysis is evaluated. It is **not worth bundling now**.

Nosh already separates identity, grams, and kcal per 100 g. Swift, not the model, computes `grams * kcalPer100g / 100`. A catalog would replace only the energy-density number, and only after a food is mapped to a real record. It does not solve visual portion error, mixed-dish double counting, or model unavailability.

The hard part is matching a photo-derived name and preparation to one catalog row. Storage size is not the hard part.

## What it would improve

- Repeatable energy density for common generic foods (rice, chicken breast, banana) instead of a new model guess each time.
- Honest provenance: a FoodData Central ID and dataset version, rather than a model-invented kcal figure.
- Portion edits stay local and deterministic once a catalog row is chosen.
- Corrections can search the catalog by name without another model call.

## What it would not improve

- Grams from a photo remain a visual guess.
- Unfamiliar dishes, sauces, and restaurant plates often have no row.
- Portuguese names and dishes are poorly covered by USDA tables.
- History must stay a snapshot. Updating the catalog must not rewrite saved meals.

## When to do it

Do it after all of these are true:

1. Photo analysis runs on the physical iPhone, including airplane mode after model assets are installed.
2. A small labeled set of meals exists (simple foods, mixed dishes, non-food).
3. Model kcal-per-100 g error is large enough, or users correct food identity often enough, that a catalog would change the product.

Until then, keep calling results estimates and do not attribute them to a database.

## How it should work in Nosh

Keep the model as a **recognizer**, not as the nutrition table.

1. The photo (or a typed correction) yields a food name, preparation, and suggested grams.
2. A local catalog search returns zero, one, or a few candidate records (same name family, raw vs cooked called out).
3. Zero matches: keep the item, mark energy unknown or fall back to a model kcal value that is labeled as a model estimate. Never treat a miss as zero.
4. One confident match, or a user pick from a short list: copy that row’s kcal per 100 g, record ID, dataset version, and preparation state into the draft.
5. Changing grams only rescales. Changing the food or cooking method invalidates the catalog row until a new match is confirmed.
6. Save stores the snapshot. Opening History does not look up the catalog again.

Suggested extra fields on a food item, without changing historical records in place:

- `energyBasis`: `catalog` or `model`
- `catalogID` (stable source ID, for example an FDC ID)
- `catalogVersion` (dataset name + release date)
- existing `kcalPer100g`, `grams`, `preparation`

Runtime lookup stays on-device. Downloads and CSV transforms belong in a development script. Do not call the USDA API, Open Food Facts, or any other network from the app.

SQLite already ships on iOS. A kcal-only table of several thousand foods is a small read-only bundle resource. JSON plus an in-memory index is also enough at that size. Do not add a persistence framework until there is a concrete query need.

## Dataset comparison

Use a **generic composition table**, not a supermarket barcode dump. Nosh estimates a plate, not a packaged SKU.

| Source | Why it fits | Why it does not | License |
| --- | --- | --- | --- |
| USDA FoodData Central SR Legacy (7,793 foods, final 2018) plus Foundation Foods | English descriptions, kcal per 100 g, stable IDs, small enough to slim down and bundle. Full branded dump is gigabytes and is the wrong product. | US foods and cooking. Weak on Portuguese dishes. | Public domain, CC0 1.0. Attribution requested, not required. |
| ANSES CIQUAL 2025 (3,484 foods) | European cooking, 74 components, Excel/XML of a few megabytes. | French-first names. Extra mapping work for an English UI. | Etalab 2.0 (open, attribution). |
| INSA PortFIR TCA | Best coverage of foods eaten in Portugal; Excel download; values per 100 g edible portion. | Download dialog is copyright / citation, not a clear open license. Bundling in the App Store needs an explicit OK from INSA. Portuguese names vs English UI. | Cite INSA; confirm redistribution before shipping. |
| Open Food Facts | Useful later for barcodes, which Nosh does not do. | ~0.9 GB gzip / ~9 GB CSV, ODbL share-alike, packaged products, crowd quality. | ODbL |

**Preferred first catalog, if this work starts:** USDA SR Legacy + Foundation Foods, energy and identity only, built at development time into a versioned SQLite or JSON resource. Keep PortFIR as a possible second table after written redistribution terms. Do not bundle Open Food Facts for plated-meal estimates.

Links:

- https://fdc.nal.usda.gov/download-datasets/
- https://fdc.nal.usda.gov/api-guide/
- https://ciqual.anses.fr/cms/en/2025-anses-ciqual-table
- https://entrepot.recherche.data.gouv.fr/dataset.xhtml?persistentId=doi:10.57745/RDMHWY
- https://portfir.insa.min-saude.pt/
- https://world.openfoodfacts.org/data
- https://opendatacommons.org/licenses/odbl/1-0/index.html

## Build pipeline (when approved)

1. Download the chosen release (not the live API).
2. Keep source ID, English name, preparation/state, kcal per 100 g, documented serving weight if present, dataset version, and source URL.
3. Drop branded products, refuse non-finite energy, keep raw vs cooked as separate rows.
4. Emit `Nosh/Resources/NutritionCatalog/<version>/` and a human-readable attribution file.
5. Unit-test search, ambiguous matches, missing energy, and that saved meals do not change when the catalog file is replaced.

## Fallback policy (draft)

When the catalog is present:

- Catalog hit after user confirmation or a single unambiguous match: `energyBasis = catalog`.
- No hit: keep the model kcal if it passed validation, labeled as a model estimate; otherwise unknown.
- Never invent a catalog ID or source URL for a model value.

This policy can change once measurement exists. It must be explicit in the UI.
