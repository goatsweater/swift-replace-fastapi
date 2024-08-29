import Fluent
import Vapor

func routes(_ app: Application) throws {
    // Login routes
    let passwordProtected = app.grouped(User.authenticator())
    passwordProtected.post("login", "access-token") { req async throws -> UserToken in
        let user = try req.auth.require(User.self)
        let token = try user.generateToken()
        try await token.save(on: req.db)
        return token
    }
    
    let tokenProtected = app.grouped(UserToken.authenticator())
    tokenProtected.post("login", "test-token") { req async throws -> UserDTO in
        try req.auth.require(User.self).toDTO()
    }
    
    // TODO: reset-password
    // TODO: password-recovery
    // TODO: password-recovery-html
    
    // Controller routes
    try app.register(collection: UserController())
    try app.register(collection: ItemController())
}
