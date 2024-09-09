import Fluent
import Vapor

struct ItemController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        // Authenticated routes
        let tokenProtected = routes.grouped(UserToken.authenticator())
        let items = tokenProtected.grouped("items")
        
        items.get(use: index)
        items.post(use: create)
        
        items.group(":id") { item in
            item.get(use: readItem)
            item.put(use: update)
            item.delete(use: delete)
        }
    }
    
    /// Generate a list of items.
    ///
    /// - Returns: A list of items.
    @Sendable
    func index(req: Request) async throws -> [ItemDTO] {
        try await Item.query(on: req.db).all().map { $0.toDTO() }
    }
    
    /// Get a specific item.
    ///
    /// - Returns: An item.
    @Sendable
    func readItem(req: Request) async throws -> ItemDTO {
        guard let item = try await Item.find(req.parameters.get("id"), on: req.db) else {
            throw Abort(.notFound)
        }
        
        return item.toDTO()
    }
    
    /// Create a new item
    ///
    ///  - Returns: An item.
    func create(req: Request) async throws -> ItemDTO {
        let user = try req.auth.require(User.self)
        guard user.isActive == true else {
            throw Abort(.unauthorized, reason: "Must be an active user to create items.")
        }
        guard let currentUserID = user.id else {
            throw Abort(.internalServerError, reason: "Could not find ID for current user")
        }
        
        try Item.Create.validate(content: req)
        let create = try req.content.decode(Item.Create.self)
        req.logger.debug("Creating item \(create.title).")
        
        let item = Item(title: create.title, description: create.description, ownerID: currentUserID)
        try await item.save(on: req.db)
        req.logger.debug("\(item.title) saved in database.")
        
        return item.toDTO()
    }
    
    /// Update an existing item.
    ///
    /// - Returns: The updated item.
    func update(req: Request) async throws -> ItemDTO {
        guard let item = try await Item.find(req.parameters.get("id"), on: req.db) else {
            throw Abort(.notFound)
        }
        
        let updatedItem = try req.content.decode(Item.self)
        item.title = updatedItem.title
        item.description = updatedItem.description
        item.$owner.id = updatedItem.$owner.id
        
        try await item.save(on: req.db)
        
        return item.toDTO()
    }
    
    /// Delete an item.
    func delete(req: Request) async throws -> HTTPStatus {
        guard let item = try await Item.find(req.parameters.get("id"), on: req.db) else {
            throw Abort(.notFound)
        }
        try await item.delete(on: req.db)
        return .ok
    }
}
