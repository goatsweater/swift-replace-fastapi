import Fluent

extension Item {
    struct CreateTableMigration: AsyncMigration {
        var name: String { "CreateItem" }
        
        func prepare(on database: any Database) async throws {
            try await database.schema("items")
                .id()
                .field("title", .string, .required)
                .field("description", .string)
                .field("owner", .uuid, .required, .references("users", "id"))
                .create()
        }
        
        func revert(on database: any Database) async throws {
            try await database.schema("items").delete()
        }
    }
}

