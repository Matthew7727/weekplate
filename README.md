# Weekplate

A bold, on-device iPhone app for weekly calorie tracking and Sunday meal prep.

## What works

- Daily or Monday–Sunday macro goals for carbs, protein and fat, with calorie targets calculated from 4/4/9 kcal per gram
- Daily/weekly calorie and macro progress; existing calorie-only logs remain intact
- Batch recipes with adjustable portions, ingredient weights, calories and macros
- Meal planning by day and meal, then one-tap logging of a planned portion
- Import `.txt` recipes as editable drafts (original text is kept in notes)
- Packaged-food text search through Search-a-licious and barcode lookup through Open Food Facts
- Camera barcode scanning and nutrition-label photography with calorie/macro OCR and manual review before logging
- Weekly adherence history, weight logs, and a four-week straight-line weight trend
- Animated launch, playful tap and logging feedback, and light, dark, and system themes

All personal data stays in the app's local Application Support folder. Packaged-food lookup needs an internet connection and depends on community-provided nutrition data. Check product labels; imported text recipes need calorie values before logging.

## Open in Xcode

Xcode Beta and [XcodeGen](https://github.com/yonaskolb/XcodeGen) are installed on this Mac. Open the generated project with:

```sh
open -a /Applications/Xcode-beta.app Weekplate.xcodeproj
```

Run `xcodegen generate` after changing `project.yml`. The deployment target is iOS 17. The app builds and launches in the iPhone 17 Pro simulator; camera scanning still requires a physical iPhone. The bundle identifier is `com.mattecc.weekplate`.
Before public release, replace the prototype Open Food Facts `User-Agent` in `OpenFoodFactsService.swift` with an app URL or contact address, as required by their API guidance.

Run the Foundation-only calculation tests with `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test`.

## Run on the plugged-in iPhone Air

The phone is paired with this Mac and Developer Mode has been enabled. In Xcode Beta, sign in under **Xcode > Settings > Apple Accounts** so automatic signing can create a development provisioning profile. The target is configured for the local Apple Development team. Then select **Matthew’s iPhone** as the run destination and press **Run**. Xcode may ask you to confirm the developer certificate or trust the app on the phone.

## Recipe text import

The importer recognises headings starting with `# ` or `Recipe:` and `---` separators. It reads a `Servings: N` line if present. Other text is preserved in the notes field, so recipes can be cleaned up in the editor without losing the original instructions. Ingredient calories or a per-portion calorie value must be supplied before a recipe can be logged.
