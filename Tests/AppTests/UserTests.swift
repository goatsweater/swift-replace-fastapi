@testable import App
import Fakery
import Fluent
import Vapor
import XCTVapor

final class UserTests: XCTestCase {
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
    
    func testListAllUsers() async throws {
        
        // Create some sample users
        let sampleUsers = [
            User(fullName: faker.name.name(), email: faker.internet.email(), isActive: true, isSuperuser: false, hashedPassword: try Bcrypt.hash(faker.internet.password())),
            User(fullName: faker.name.name(), email: faker.internet.email(), isActive: true, isSuperuser: true, hashedPassword: try Bcrypt.hash(faker.internet.password())),
            ]
        try await sampleUsers.create(on: self.app.db)
        
        try await self.app.test(.GET, "users", afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            
            let allUsers = try res.content.decode([UserDTO].self)
            XCTAssertEqual(allUsers.count, 3)
        })
    }
    
    func testCreateUserWithoutLogin() async throws {
        let nonAuthUser = User.Create(fullName: "Nonauth User", email: "nonauth@example.com", password: "simplepassword", confirmPassword: "simplepassword", isActive: true, isSuperuser: false)
        try await self.app.test(.POST, "users", beforeRequest: { req in
            try req.content.encode(nonAuthUser)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .unauthorized)
        })
    }
    
    func testCreateUserAsNormalUser() async throws {
        // Register a user to act as
        let email = faker.internet.email()
        let password = faker.internet.password()
        let me = User(fullName: faker.name.name(), email: email, isActive: true, isSuperuser: false, hashedPassword: try Bcrypt.hash(password))
        try await me.save(on: self.app.db)
        
        let myToken = try me.generateToken()
        try await myToken.save(on: self.app.db)
        
        // Create a user we want to try to register
        let newUser = User.Create(fullName: "Normal User", email: "normal@example.com", password: "simplepassword", confirmPassword: "simplepassword", isActive: true, isSuperuser: false)
        
        try await self.app.test(.POST, "users", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: myToken.value)
            try req.content.encode(newUser)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .unauthorized)
        })
    }
    
    func testCreateUserNewEmail() async throws {
        // Register a user to act as
        let email = faker.internet.email()
        let password = faker.internet.password()
        let me = User(fullName: faker.name.name(), email: email, isActive: true, isSuperuser: true, hashedPassword: try Bcrypt.hash(password))
        try await me.save(on: self.app.db)
        
        let myToken = try me.generateToken()
        try await myToken.save(on: self.app.db)
        
        // Create a user we want to try to register
        let newUser = User.Create(fullName: "Normal User", email: "normal@example.com", password: "simplepassword", confirmPassword: "simplepassword", isActive: true, isSuperuser: false)
        
        try await self.app.test(.POST, "users", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: myToken.value)
            try req.content.encode(newUser)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            
            let createdUser = try res.content.decode(UserDTO.self)
            XCTAssertEqual(createdUser.fullName, newUser.fullName)
            XCTAssertEqual(createdUser.email, newUser.email)
            XCTAssertEqual(createdUser.isActive, newUser.isActive)
            XCTAssertEqual(createdUser.isSuperuser, newUser.isSuperuser)
            XCTAssertNotNil(createdUser.id)
        })
        
        // Look the user up in the DB
        let savedUser = try await User.query(on: self.app.db).filter(\.$email == newUser.email).first()
        
        if let user = savedUser {
            XCTAssertEqual(user.email, newUser.email)
        } else {
            XCTFail("Unable to retrieve created user \(newUser.email)")
        }
    }
    
    func testGetUsersSuperuserMe() async throws {
        let firstUser = try await User.query(on: self.app.db).filter(\.$email == self.firstUserEmail).first()
        let firstUserToken = try XCTUnwrap(firstUser?.generateToken())
        try await firstUserToken.save(on: self.app.db)
        
        try await self.app.test(.GET, "users/me", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: firstUserToken.value)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            
            let currentUser = try res.content.decode(UserDTO.self)
            XCTAssertTrue(currentUser.isActive)
            XCTAssertTrue(currentUser.isSuperuser)
            XCTAssertEqual(currentUser.email, self.firstUserEmail)
        })
    }
    
    func testGetUsersNormalUserMe() async throws {
        // Register a user to act as
        let me = User(fullName: faker.name.name(), email: faker.internet.email(), isActive: true, isSuperuser: false, hashedPassword: try Bcrypt.hash(faker.internet.password()))
        try await me.save(on: self.app.db)
        
        let myToken = try me.generateToken()
        try await myToken.save(on: self.app.db)
        
        try await self.app.test(.GET, "users/me", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: myToken.value)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            
            let currentUser = try res.content.decode(UserDTO.self)
            XCTAssertTrue(currentUser.isActive)
            XCTAssertFalse(currentUser.isSuperuser)
            XCTAssertEqual(currentUser.email, me.email)
        })
    }
    
    func testGetExistingUser() async throws {
        let sampleUser = User(fullName: faker.name.name(), email: faker.internet.email(), isActive: true, isSuperuser: false, hashedPassword: try Bcrypt.hash(faker.internet.password()))
        try await sampleUser.save(on: self.app.db)
        
        let firstUser = try await User.query(on: self.app.db).filter(\.$email == self.firstUserEmail).first()
        let firstUserToken = try XCTUnwrap(firstUser?.generateToken())
        try await firstUserToken.save(on: self.app.db)
        
        // Look up the ID of the user we created so we can form a request based on it
        let searchUser = try await User.query(on: self.app.db).filter(\.$email == sampleUser.email).first()
        let searchUserId = try XCTUnwrap(searchUser?.id)
        try await self.app.test(.GET, "users/\(searchUserId)", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: firstUserToken.value)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            
            let chosenUser = try res.content.decode(UserDTO.self)
            XCTAssertEqual(chosenUser.email, sampleUser.email)
        })
    }
}
