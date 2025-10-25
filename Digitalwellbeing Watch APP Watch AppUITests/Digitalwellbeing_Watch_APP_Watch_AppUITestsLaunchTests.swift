//
//  Digitalwellbeing_Watch_APP_Watch_AppUITestsLaunchTests.swift
//  Digitalwellbeing Watch APP Watch AppUITests
//
//  Created by farhan akhtar on 18/09/25.
//

import XCTest

final class Digitalwellbeing_Watch_APP_Watch_AppUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
