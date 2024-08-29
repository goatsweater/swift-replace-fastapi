import Fluent
import struct Foundation.UUID

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
