//
//  pkwifiTests.swift
//  pkwifiTests
//
//  Created by YUN YOUNG LEE on 2018. 1. 7..
//  Copyright © 2018년 YUN YOUNG LEE. All rights reserved.
//

import XCTest
@testable import pkimport

class pkwifiTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testDecodeModel() {
        let bundle = Bundle(for: type(of: self))
        let data = try! Data(contentsOf: bundle.url(forResource: "list", withExtension: "json")!)
        let response = try! JSONDecoder().decode(PhotoListResponse.self, from: data)
        let photos = response.photos
        XCTAssertEqual(103, photos.count)
    }
    
    func testExample() {
        
        
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
