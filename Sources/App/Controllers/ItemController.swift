import Fluent
import Vapor

struct ItemController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let items = routes.grouped("items")
        
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
        
        let itemDTO = ItemDTO(id: item.id, title: item.title, ownerID: item.$owner.id)
        return itemDTO
    }
    
    /// Create a new item
    ///
    ///  - Returns: An item.
    func create(req: Request) async throws -> ItemDTO {
        let item = try req.content.decode(Item.self)
        try await item.save(on: req.db)
        
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
