import Fluent
import struct Foundation.UUID
import Vapor

final class User: Model {
    static let schema = "users"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "full_name")
    var fullName: String
    
    @Field(key: "email")
    var email: String
    
    @Field(key: "is_active")
    var isActive: Bool
    
    @Field(key: "is_superuser")
    var isSuperuser: Bool
    
    @Field(key: "hashed_password")
    var hashedPassword: String
    
    @Children(for: \.$owner)
    var items: [Item]
    
    // Initializers
    init() { }
    
    init(id: UUID? = nil, fullName: String, email: String, isActive: Bool, isSuperuser: Bool, hashedPassword: String) {
        self.id = id
        self.fullName = fullName
        self.email = email
        self.isActive = isActive
        self.isSuperuser = isSuperuser
        self.hashedPassword = hashedPassword
    }
    
    // DTO
    func toDTO() -> UserDTO {
        .init(id: self.id, fullName: self.fullName, email: self.email, isActive: self.isActive, isSuperuser: self.isSuperuser)
    }
}

// Struct used for creating a new user
extension User {
    struct Create: Content {
        var fullName: String
        var email: String
        var password: String
        var confirmPassword: String
        
        var isActive: Bool
        var isSuperuser: Bool
    }
    
    struct UpdatePassword: Content {
        var currentPassword: String
        var newPassword: String
    }
}

// Validate the data on user creation
extension User.Create: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("fullName", as: String.self, is: !.empty)
        validations.add("email", as: String.self, is: .email)
        validations.add("password", as: String.self, is: .count(8...))
    }
}

// Enable authentication on the user model
extension User: ModelAuthenticatable {
    static let usernameKey = \User.$email
    static let passwordHashKey = \User.$hashedPassword
    
    func verify(password: String) throws -> Bool {
        try Bcrypt.verify(password, created: self.hashedPassword)
    }
}
