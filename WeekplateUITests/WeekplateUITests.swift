import XCTest

final class WeekplateUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestingResetData"]
        app.launch()
        XCTAssertTrue(app.buttons["Week"].waitForExistence(timeout: 8))
    }

    func testUserCanMoveAcrossEveryMainTab() {
        for tab in ["Recipes", "Find", "Trends", "You", "Week"] {
            let button = app.buttons[tab]
            XCTAssertTrue(button.exists, "Expected the \(tab) tab to be visible")
            button.tap()
            XCTAssertTrue(button.exists)
        }
    }

    func testUserCanCreateRecipeWithIngredientAndNutrition() {
        app.buttons["Recipes"].tap()
        app.buttons["New recipe"].tap()

        let name = app.textFields["Name"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.tap()
        name.typeText("Weeknight curry")
        app.buttons["Add ingredient"].tap()

        let ingredient = app.textFields["Ingredient"]
        XCTAssertTrue(ingredient.exists)
        ingredient.tap()
        ingredient.typeText("Chickpeas")
        app.textFields["Kcal / 100g"].tap()
        app.textFields["Kcal / 100g"].typeText("164")
        app.buttons["Save"].tap()

        XCTAssertTrue(app.buttons["recipe.Weeknight curry"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'kcal / portion'")).firstMatch.exists)
    }

    func testUserCanCreateRecipeAndLogSelectedPortion() {
        createManualRecipe(name: "Quick oats", calories: "320")
        app.buttons["recipe.Quick oats"].tap()

        XCTAssertTrue(app.buttons["Log now"].waitForExistence(timeout: 3))
        app.buttons["Log now"].tap()
        app.buttons["Week"].tap()

        XCTAssertTrue(element("entry.Quick oats").waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["320 kcal"].exists)
    }

    func testUserCanPlanRecipeThenSeeItOnTheWeek() {
        createManualRecipe(name: "Prep bowl", calories: "450")
        app.buttons["Week"].tap()
        app.buttons["Plan"].tap()

        XCTAssertTrue(app.staticTexts["Plan a meal"].waitForExistence(timeout: 3))
        app.buttons["Recipe"].tap()
        app.buttons["Prep bowl"].tap()
        app.buttons["Add"].tap()

        XCTAssertTrue(element("plan.Prep bowl").waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Eat"].exists)
    }

    func testUserCanLogManualFoodWithMacros() {
        app.buttons["Week"].tap()
        app.buttons["Log something else"].tap()

        app.textFields["What did you eat?"].tap()
        app.textFields["What did you eat?"].typeText("Avocado toast")
        app.textFields["Carbs"].tap()
        app.textFields["Carbs"].typeText("30")
        app.textFields["Protein"].tap()
        app.textFields["Protein"].typeText("10")
        app.textFields["Fat"].tap()
        app.textFields["Fat"].typeText("15")
        app.buttons["Save"].tap()

        XCTAssertTrue(element("entry.Avocado toast").waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["295 kcal"].exists)
    }

    func testUserCanOpenEveryFindFoodInputPath() {
        app.buttons["Find"].tap()
        XCTAssertTrue(app.textFields["Try oats, yoghurt, pasta…"].exists)
        XCTAssertTrue(app.textFields["Barcode number"].exists)
        XCTAssertTrue(app.buttons["Add manually"].exists)
        XCTAssertTrue(app.buttons["Or choose a nutrition-label photo"].exists)
    }

    func testUserCanSetGoalAndWeightInSettings() {
        app.buttons["You"].tap()
        XCTAssertTrue(app.buttons["Set goal"].waitForExistence(timeout: 3))

        app.textFields["Carbs"].tap()
        app.textFields["Carbs"].doubleTap()
        app.textFields["Carbs"].typeText("200")
        app.textFields["Protein"].tap()
        app.textFields["Protein"].doubleTap()
        app.textFields["Protein"].typeText("150")
        app.textFields["Fat"].tap()
        app.textFields["Fat"].doubleTap()
        app.textFields["Fat"].typeText("70")
        app.buttons["Set goal"].tap()

        app.textFields["New weigh-in (kg)"].tap()
        app.textFields["New weigh-in (kg)"].typeText("78.4")
        app.buttons["Add weigh-in"].tap()
        XCTAssertTrue(app.staticTexts["latest-weight"].waitForExistence(timeout: 3))

        app.textFields["Target weight in kg (optional)"].tap()
        app.textFields["Target weight in kg (optional)"].typeText("72")
        app.buttons["Save weight target"].tap()
        app.buttons["Trends"].tap()
        XCTAssertTrue(app.staticTexts["target-weight"].waitForExistence(timeout: 3))
    }

    func testUserCanOpenTrendsWithNoData() {
        app.buttons["Trends"].tap()
        XCTAssertTrue(app.staticTexts["TRENDS."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["—"].exists)
        XCTAssertTrue(app.staticTexts["Add weigh-ins in You to see a trend and a four-week projection."].exists)
    }

    private func createManualRecipe(name: String, calories: String) {
        app.buttons["Recipes"].tap()
        app.buttons["New recipe"].tap()
        app.textFields["Name"].tap()
        app.textFields["Name"].typeText(name)
        app.textFields["Kcal per portion (optional)"].tap()
        app.textFields["Kcal per portion (optional)"].typeText(calories)
        app.buttons["Save"].tap()
        XCTAssertTrue(app.buttons["recipe.\(name)"].waitForExistence(timeout: 3))
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}