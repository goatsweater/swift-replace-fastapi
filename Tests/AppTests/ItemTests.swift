@testable import App
import Fakery
import Fluent
import Vapor
import XCTVapor

final class ItemTests: XCTestCase {
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
        // Clean up any items
        let registeredItems = try await Item.query(on: self.app.db).all()
        try await registeredItems.delete(on: self.app.db)
        
        // Clean up any tokens
        let registeredTokens = try await UserToken.query(on: self.app.db).all()
        try await registeredTokens.delete(on: self.app.db)
        
        try await app.autoRevert()
        try await self.app.asyncShutdown()
        self.app = nil
    }
    
    func testCreateItem() async throws {
        let firstUser = try await User.query(on: self.app.db).filter(\.$email == self.firstUserEmail).first()
        let firstUserToken = try XCTUnwrap(firstUser?.generateToken())
        try await firstUserToken.save(on: self.app.db)

        let newItem = Item.Create(title: "Foo", description: "Fighters")
        
        try await self.app.test(.POST, "items", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: firstUserToken.value)
            try req.content.encode(newItem)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            
            let createdItem = try res.content.decode(ItemDTO.self)
            XCTAssertEqual(createdItem.title, newItem.title)
            XCTAssertEqual(createdItem.description, newItem.description)
            
            XCTAssertNotNil(createdItem.ownerID)
        })
    }
    
    func testReadItem() async throws {
        let firstUser = try await User.query(on: self.app.db).filter(\.$email == self.firstUserEmail).first()
        let firstUserToken = try XCTUnwrap(firstUser?.generateToken())
        try await firstUserToken.save(on: self.app.db)

        let item = try Item(title: faker.commerce.productName(), description: faker.commerce.department(), ownerID: XCTUnwrap(firstUser?.id))
        try await item.save(on: self.app.db)
        
        let itemId = try item.requireID()
        try await self.app.test(.GET, "items/\(itemId)", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: firstUserToken.value)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            
            let retrievedItem = try res.content.decode(ItemDTO.self)
            XCTAssertEqual(retrievedItem.id, item.id)
            XCTAssertEqual(retrievedItem.title, item.title)
            XCTAssertEqual(retrievedItem.description, item.description)
            XCTAssertEqual(retrievedItem.ownerID, item.$owner.id)
        })
    }
    
    func testReadItemNotFound() async throws {
        let firstUser = try await User.query(on: self.app.db).filter(\.$email == self.firstUserEmail).first()
        let firstUserToken = try XCTUnwrap(firstUser?.generateToken())
        try await firstUserToken.save(on: self.app.db)
        
        try await self.app.test(.GET, "items/\(UUID())", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: firstUserToken.value)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .notFound)
        })
    }
    
    func testReadItemNotEnoughPermissions()  async throws {
        let firstUser = try await User.query(on: self.app.db).filter(\.$email == self.firstUserEmail).first()
        
        let sampleUser = User(fullName: faker.name.name(), email: faker.internet.email(), isActive: true, isSuperuser: false, hashedPassword: try Bcrypt.hash(faker.internet.password()))
        try await sampleUser.save(on: self.app.db)
        let sampleUserToken = try sampleUser.generateToken()
        try await sampleUserToken.save(on: self.app.db)

        let item = try Item(title: faker.commerce.productName(), description: faker.commerce.department(), ownerID: XCTUnwrap(firstUser?.id))
        try await item.save(on: self.app.db)
        
        let itemId = try item.requireID()
        try await self.app.test(.GET, "items/\(itemId)", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: sampleUserToken.value)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .forbidden)
        })
    }
    
    func testReadItems() async throws {
        let firstUser = try await User.query(on: self.app.db).filter(\.$email == self.firstUserEmail).first()
        let firstUserToken = try XCTUnwrap(firstUser?.generateToken())
        try await firstUserToken.save(on: self.app.db)
        
        let items = try [
            Item(title: faker.commerce.productName(), description: faker.commerce.department(), ownerID: XCTUnwrap(firstUser?.id)),
            Item(title: faker.commerce.productName(), description: faker.commerce.department(), ownerID: XCTUnwrap(firstUser?.id))
        ]
        try await items.create(on: self.app.db)
        
        try await self.app.test(.GET, "items", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: firstUserToken.value)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            
            let retrievedItems = try res.content.decode([ItemDTO].self)
            XCTAssertEqual(retrievedItems.count, 2)
        })
    }
    
    func testUpdateItem() async throws {
        let firstUser = try await User.query(on: self.app.db).filter(\.$email == self.firstUserEmail).first()
        let firstUserToken = try XCTUnwrap(firstUser?.generateToken())
        try await firstUserToken.save(on: self.app.db)

        let item = try Item(title: faker.commerce.productName(), description: faker.commerce.department(), ownerID: XCTUnwrap(firstUser?.id))
        try await item.save(on: self.app.db)
        
        let updatedItem = ItemDTO(title: "Updated", description: "New description", ownerID: try XCTUnwrap(firstUser?.id))
        
        let itemId = try item.requireID()
        try await self.app.test(.PUT, "items/\(itemId)", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: firstUserToken.value)
            try req.content.encode(updatedItem)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            
            let responseItem = try res.content.decode(ItemDTO.self)
            XCTAssertEqual(responseItem.title, updatedItem.title)
            XCTAssertEqual(responseItem.description, updatedItem.description)
        })
    }
    
    func testUpdateItemNotFound() async throws {
        let firstUser = try await User.query(on: self.app.db).filter(\.$email == self.firstUserEmail).first()
        let firstUserToken = try XCTUnwrap(firstUser?.generateToken())
        try await firstUserToken.save(on: self.app.db)
        
        let updatedItem = ItemDTO(title: "Updated", description: "New description", ownerID: try XCTUnwrap(firstUser?.id))
        
        try await self.app.test(.PUT, "items/\(UUID())", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: firstUserToken.value)
            try req.content.encode(updatedItem)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .notFound)
        })
    }
    
    func testUpdateItemNotEnoughPermissions() async throws {
        let firstUser = try await User.query(on: self.app.db).filter(\.$email == self.firstUserEmail).first()
        
        let sampleUser = User(fullName: faker.name.name(), email: faker.internet.email(), isActive: true, isSuperuser: false, hashedPassword: try Bcrypt.hash(faker.internet.password()))
        try await sampleUser.save(on: self.app.db)
        let sampleUserToken = try sampleUser.generateToken()
        try await sampleUserToken.save(on: self.app.db)

        let item = try Item(title: faker.commerce.productName(), description: faker.commerce.department(), ownerID: XCTUnwrap(firstUser?.id))
        try await item.save(on: self.app.db)
        
        let updatedItem = ItemDTO(title: "Updated", description: "New description", ownerID: try XCTUnwrap(firstUser?.id))
        
        let itemId = try item.requireID()
        try await self.app.test(.PUT, "items/\(itemId)", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: sampleUserToken.value)
            try req.content.encode(updatedItem)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .forbidden)
        })
    }
    
    func testDeleteItem() async throws {
        let firstUser = try await User.query(on: self.app.db).filter(\.$email == self.firstUserEmail).first()
        let firstUserToken = try XCTUnwrap(firstUser?.generateToken())
        try await firstUserToken.save(on: self.app.db)
        
        let item = try Item(title: faker.commerce.productName(), description: faker.commerce.department(), ownerID: XCTUnwrap(firstUser?.id))
        try await item.save(on: self.app.db)
        
        let itemId = try item.requireID()
        try await self.app.test(.DELETE, "items/\(itemId)", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: firstUserToken.value)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
        })
    }
    
    func testDeleteItemNotFound() async throws {
        let firstUser = try await User.query(on: self.app.db).filter(\.$email == self.firstUserEmail).first()
        let firstUserToken = try XCTUnwrap(firstUser?.generateToken())
        try await firstUserToken.save(on: self.app.db)
        
        try await self.app.test(.DELETE, "items/\(UUID())", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: firstUserToken.value)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .notFound)
        })
    }
    
    func testDeleteItemNotEnoughPermissions() async throws {
        let firstUser = try await User.query(on: self.app.db).filter(\.$email == self.firstUserEmail).first()
        
        let sampleUser = User(fullName: faker.name.name(), email: faker.internet.email(), isActive: true, isSuperuser: false, hashedPassword: try Bcrypt.hash(faker.internet.password()))
        try await sampleUser.save(on: self.app.db)
        let sampleUserToken = try sampleUser.generateToken()
        try await sampleUserToken.save(on: self.app.db)

        let item = try Item(title: faker.commerce.productName(), description: faker.commerce.department(), ownerID: XCTUnwrap(firstUser?.id))
        try await item.save(on: self.app.db)
        
        let itemId = try item.requireID()
        try await self.app.test(.DELETE, "items/\(itemId)", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: sampleUserToken.value)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .forbidden)
        })
    }
}
