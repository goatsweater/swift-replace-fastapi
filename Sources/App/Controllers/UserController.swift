import Vapor
import Fluent

struct UserController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        // Public routes
        let users = routes.grouped("users")
        users.get(use: index)
        users.post("signup", use: register)
        
        // Authenticated routes
        let tokenProtected = users.grouped(UserToken.authenticator())
        tokenProtected.post(use: create)
        
        tokenProtected.group(":id") { userID in
            userID.get(use: readUser)
            userID.patch(use: updateUser)
            userID.delete(use: deleteUser)
        }
        
        tokenProtected.group("me") { me in
            me.get(use: showMe)
            me.patch(use: updateMe)
            me.delete(use: deleteMe)
            me.patch("password", use: resetPassword)
        }
        
        /// List all users
        ///
        /// - Returns: A list of users
        func index(req: Request) async throws -> [UserDTO] {
            try await User.query(on: req.db).all().map { $0.toDTO() }
        }
        
        /// Create a new user from a superuser account
        ///
        ///  - Returns: Details about the new user.
        func create(req: Request) async throws -> UserDTO {
            let user = try req.auth.require(User.self)
            guard user.isSuperuser == true else {
                throw Abort(.unauthorized, reason: "Must be superuser to register others ")
            }
            // Validate the inputs meet minimum expectations
            try User.Create.validate(content: req)
            let create = try req.content.decode(User.Create.self)
            // Check the password matches confirmation
            guard create.password == create.confirmPassword else {
                throw Abort(.badRequest, reason: "Passwords did not match")
            }
            
            let newUser = try User(
                fullName: create.fullName,
                email: create.email,
                isActive: create.isActive,
                isSuperuser: create.isSuperuser,
                hashedPassword: Bcrypt.hash(create.password)
            )
            try await newUser.save(on: req.db)
            
            // TODO: send an email to the new user
            
            return newUser.toDTO()
        }
        
        /// Get information about the current user
        func showMe(req: Request) async throws -> UserDTO {
            try req.auth.require(User.self).toDTO()
        }
        
        /// Update current user information
        func updateMe(req: Request) async throws -> UserDTO {
            let user = try req.auth.require(User.self)
            
            let updatedUser = try req.content.decode(UserDTO.self)
            user.email = updatedUser.email
            user.fullName = updatedUser.fullName
            
            try await user.save(on: req.db)
            
            return user.toDTO()
        }
        
        /// Delete the current user
        func deleteMe(req: Request) async throws -> HTTPStatus {
            let user = try req.auth.require(User.self)
            try await user.delete(on: req.db)
            return .ok
        }
        
        /// Reset the user's password
        func resetPassword(req: Request) async throws -> HTTPStatus {
            let user = try req.auth.require(User.self)
            let updatedPassword = try req.content.decode(User.UpdatePassword.self)
            
            // Make sure their old password matches what the saved value
            let oldPasswordHashed = try Bcrypt.hash(updatedPassword.currentPassword)
            guard oldPasswordHashed == user.hashedPassword else {
                throw Abort(.badRequest, reason: "Current password did not match")
            }
            
            user.hashedPassword = try Bcrypt.hash(updatedPassword.newPassword)
            try await user.save(on: req.db)
            
            return .ok
        }
        
        /// Allow a user to register
        func register(req: Request) async throws -> UserDTO {
            try User.Create.validate(content: req)
            let registration = try req.content.decode(User.Create.self)
            
            // Make sure there's no conflict with existing users
            let existing = try await User.query(on: req.db)
                .filter(\.$email == registration.email)
                .first()
            guard existing == nil else {
                throw Abort(.badRequest, reason: "User exists")
            }
            
            let newUser = try User(
                fullName: registration.fullName,
                email: registration.email,
                isActive: registration.isActive,
                isSuperuser: registration.isSuperuser,
                hashedPassword: Bcrypt.hash(registration.password)
            )
            try await newUser.save(on: req.db)
            
            return newUser.toDTO()
        }
        
        /// Get information about a specific user
        func readUser(req: Request) async throws -> UserDTO {
            let currentUser = try req.auth.require(User.self)
            let requestedID = req.parameters.get("id", as: UUID.self) ?? UUID()  // In case the parameter wasn't a valid ID
            
            // Allow the user to look at themselves
            if currentUser.id == requestedID {
                return currentUser.toDTO()
            }
            
            // Only superusers can look at other users
            guard currentUser.isSuperuser == true else {
                throw Abort(.unauthorized)
            }
            
            guard let userDetails = try await User.query(on: req.db).filter(\.$id == requestedID).first() else {
                throw Abort(.badRequest, reason: "Could not find user with requested ID")
            }
            
            return userDetails.toDTO()
        }
        
        /// Update information about a specific user
        func updateUser(req: Request) async throws -> UserDTO {
            let currentUser = try req.auth.require(User.self)
            let requestedID = req.parameters.get("id", as: UUID.self) ?? UUID()  // In case the parameter wasn't a valid ID
            
            // Allow the user to look at themselves
            if currentUser.id == requestedID {
                return currentUser.toDTO()
            }
            
            // Only superusers can look at other users
            guard currentUser.isSuperuser == true else {
                throw Abort(.unauthorized)
            }
            
            let updatedUser = try req.content.decode(UserDTO.self)
            
            guard let existingUser = try await User.query(on: req.db).filter(\.$id == requestedID).first() else {
                throw Abort(.badRequest, reason: "Could not find user with requested ID")
            }
            
            existingUser.fullName = updatedUser.fullName
            existingUser.email = updatedUser.email
            existingUser.isActive = updatedUser.isActive
            existingUser.isSuperuser = updatedUser.isSuperuser
            
            try await existingUser.save(on: req.db)
            
            return existingUser.toDTO()
        }
        
        /// Delete a user
        func deleteUser(req: Request) async throws -> HTTPStatus {
            let currentUser = try req.auth.require(User.self)
            let requestedID = req.parameters.get("id", as: UUID.self) ?? UUID()  // In case the parameter wasn't a valid ID
            
            // Don't delete yourself here
            guard currentUser.id == requestedID else {
                throw Abort(.badRequest, reason: "Super users are not allowed to delete themselves.")
            }
            
            // Only superusers can look at other users
            guard currentUser.isSuperuser == true else {
                throw Abort(.unauthorized)
            }
            
            guard let existingUser = try await User.query(on: req.db).filter(\.$id == requestedID).first() else {
                throw Abort(.badRequest, reason: "Could not find user with requested ID")
            }
            
            try await existingUser.delete(on: req.db)
            return .ok
        }
    }
}
