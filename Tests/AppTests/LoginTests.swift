@testable import App
import Fakery
import Fluent
import Vapor
import XCTVapor

final class LoginTests: XCTestCase {
    var app: Application!
    let faker = Faker()
    
    // some sample users
    let firstUserEmail = Environment.get("FIRST_SUPERUSER") ?? "admin@example.com"
    let firstUserPassword = Environment.get("FIRST_SUPERUSER_PASSWORD") ?? "changethis"
    
    override func setUp() async throws {
        self.app = try await Application.make(.testing)
        try await configure(app)
        try await app.autoMigrate()
    }
    
    override func tearDown() async throws {
        // Clean up any tokens
        let registeredTokens = try await UserToken.query(on: self.app.db).all()
        try await registeredTokens.delete(on: self.app.db)
        
        try await app.autoRevert()
        try await self.app.asyncShutdown()
        self.app = nil
    }
    
    func testGetAccessToken() async throws {
        let firstUserEmail = Environment.get("FIRST_SUPERUSER") ?? "admin@example.com"
        let firstUserPassword = Environment.get("FIRST_SUPERUSER_PASSWORD") ?? "changethis"
        
        try await self.app.test(.POST, "login/access-token", beforeRequest: { req in
            try req.headers.basicAuthorization = BasicAuthorization(username: firstUserEmail, password: firstUserPassword)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            
            let token = try res.content.decode(UserToken.self)
            let registeredToken = try await UserToken.query(on: self.app.db).filter(\.$value == token.value).first()
            XCTAssertEqual(registeredToken?.value, token.value)
        })
    }
}
