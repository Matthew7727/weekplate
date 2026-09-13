# AI Capture Plan

## Goal

The first AI release is a Claude-powered recipe builder. People opt in with their own Claude Console API key, stored device-only in the iOS Keychain. Their iPhone calls Claude directly; Weekplate does not operate an AI backend or receive API keys.

The builder accepts per-portion macro targets, portions, preferred pantry ingredients, a cuisine/vibe, and practical constraints. Claude returns an editable recipe draft using ordinary UK-supermarket ingredients. Weekplate calculates ingredient, batch and per-portion macros locally and flags nutrition for newly suggested ingredients as an estimate.

The original photo-capture work below remains a later release. A shared-key implementation of that feature must use a backend; never embed a shared provider key in the iOS app.

Use the Claude API to turn photos of nutrition labels and recipes into editable Weekplate data. AI assists extraction; the person always reviews and confirms it before it is saved.

## First release: nutrition-label capture

1. The person scans a barcode first when one is available. Use the existing Open Food Facts lookup result when it is sufficient.
2. When no usable result exists, they photograph the nutrition label. The existing on-device Vision OCR gives an immediate offline result.
3. The app sends a resized image and its OCR text to a small, authenticated backend endpoint.
4. The backend calls Claude Vision and requests schema-constrained JSON with product name, nutrition basis (per 100 g/ml or serving), serving size, calories, carbohydrates, protein, fat, confidence, and warnings.
5. The app validates the response, compares macro calories with declared calories, and displays the editable review screen. Nothing is silently saved.

## Second release: recipe-photo import

1. The person photographs a recipe page/card or selects screenshots.
2. Claude returns title, servings, ingredients with amounts/units, method, and source notes.
3. Weekplate creates an editable recipe draft and preserves the original source text/image reference.
4. Nutrition is only populated when it appears on the source; later, ingredient matching can provide clearly labelled estimates.

## Architecture

```
iPhone -> Weekplate backend -> Claude Messages API -> validated JSON -> editable iPhone form
```

- Do not embed the Anthropic API key in the iOS app.
- Resize/compress images before upload; reject unsupported or oversized files.
- Keep images only for the duration needed to process a request unless the user explicitly chooses otherwise.
- Rate-limit requests, enforce the output schema server-side, and log anonymous failure categories (not image contents) to improve prompts.

## Quality safeguards

- Instruct Claude to use `null` for unreadable or missing values and never infer nutrition facts.
- Present source basis prominently: per serving vs per 100 g/ml.
- Flag ambiguous serving sizes, low confidence, and calorie/macro mismatches.
- Test with at least 50–100 real labels: glare, angles, tiny type, multilingual labels, servings and 100 g/ml layouts.

## Delivery order

1. Backend plus nutrition-label parser and response validation.
2. Connect it to the current camera/OCR review flow, retaining OCR-only offline fallback.
3. Reliability and privacy testing.
4. Recipe-photo drafts.
