import Fluent
import Vapor

extension User {
    struct AddSuperuser: AsyncMigration {
        var name: String { "AddSuperuser" }
        
        func prepare(on database: any Database) async throws {
            let firstUser = User()
            firstUser.fullName = "Administrator"
            firstUser.email = Environment.get("FIRST_SUPERUSER") ?? "admin@example.com"
            firstUser.hashedPassword = try Bcrypt.hash(Environment.get("FIRST_SUPERUSER_PASSWORD") ?? "changethis")
            firstUser.isActive = true
            firstUser.isSuperuser = true
            
            try await firstUser.save(on: database)
        }
        
        func revert(on database: any Database) async throws {
            let superuserEmail = Environment.get("FIRST_SUPERUSER") ?? "admin@example.com"
            try await User.query(on: database).filter(\.$email == superuserEmail).delete()
        }
    }
}
