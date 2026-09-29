import XCTest
import UIKit
@testable import SophiaScriptura

final class ScriptureAppearanceTests: XCTestCase {
    func testLegacyPreferencesDecodeWithoutResettingProgress() throws {
        let data = Data(#"{"preferredEdition":"api.bible.saved","typeface":"Palatino","sizeStep":4,"theme":"dark","controlsExpanded":false}"#.utf8)
        let preferences = try JSONDecoder().decode(ReaderPreferences.self,from:data)
        XCTAssertEqual(preferences.preferredEdition,"api.bible.saved")
        XCTAssertEqual(preferences.typeface,"Palatino")
        XCTAssertEqual(preferences.sizeStep,4)
        XCTAssertEqual(preferences.appearance,.oldPaper)
        XCTAssertNil(preferences.appearancePreset)
    }
    func testAllPresetsPersistAndUnknownPresetFallsBack() throws {
        for appearance in ScriptureAppearance.allCases {
            var preferences = ReaderPreferences()
            preferences.appearancePreset = appearance.rawValue
            let restored = try JSONDecoder().decode(ReaderPreferences.self,from:JSONEncoder().encode(preferences))
            XCTAssertEqual(restored.appearance,appearance)
        }
        var future = ReaderPreferences()
        future.appearancePreset = "future-preset"
        XCTAssertEqual(future.appearance,.oldPaper)
    }
    func testBundledFontFamiliesResolveWithoutFallback() {
        for preset in ScriptureAppearance.allCases {
            for family in [preset.readingFamily,preset.headingFamily,preset.interfaceFamily] where family != "System" {
                XCTAssertEqual(ScriptureFonts.font(family,size:23).familyName,family)
            }
        }
    }
    func testPaletteTextContrastInBothAppearances() {
        func luminance(_ color: UIColor) -> Double {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getRed(&r,green:&g,blue:&b,alpha:&a)
            func linear(_ v: CGFloat) -> Double { let x = Double(v); return x <= 0.04045 ? x / 12.92 : pow((x + 0.055) / 1.055,2.4) }
            return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
        }
        for preset in ScriptureAppearance.allCases {
            for dark in [false,true] {
                let palette = preset.palette(dark:dark)
                for color in [palette.ink,palette.accent] {
                    let a = luminance(color), b = luminance(palette.paper)
                    XCTAssertGreaterThanOrEqual((max(a,b)+0.05)/(min(a,b)+0.05),4.5,preset.title)
                }
            }
        }
    }
}
