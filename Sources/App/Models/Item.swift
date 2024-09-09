import Fluent
import struct Foundation.UUID
import Vapor

final class Item: Model {
    static let schema = "items"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "title")
    var title: String
    
    @Field(key: "description")
    var description: String?
    
    @Parent(key: "owner")
    var owner: User
    
    // Initializers
    init() { }
    
    init(id: UUID? = nil, title: String, description: String? = nil, ownerID: User.IDValue) {
        self.id = id
        self.title = title
        self.description = description
        self.$owner.id = ownerID
    }
    
    // DTO
    func toDTO() -> ItemDTO {
        .init(id: self.id, title: self.title, description: self.description, ownerID: self.$owner.id)
    }
}

extension Item {
    struct Create: Content {
        var title: String
        var description: String?
    }
}

extension Item.Create: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("title", as: String.self, is: !.empty)
    }
}
