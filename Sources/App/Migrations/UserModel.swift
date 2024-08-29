import Fluent

extension User {
    struct CreateTableMigration: AsyncMigration {
        var name: String { "CreateUser" }
        
        func prepare(on database: any Database) async throws {
            try await database.schema("users")
                .id()
                .field("full_name", .string, .required)
                .field("email", .string, .required)
                .field("is_active", .bool, .required, .sql(.default(true)))
                .field("is_superuser", .bool, .required, .sql(.default(false)))
                .field("hashed_password", .string, .required)
                .unique(on: "email")
                .create()
        }
        
        func revert(on database: any Database) async throws {
            try await database.schema("users").delete()
        }
    }
}
