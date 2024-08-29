import Fluent
import Vapor

struct ItemDTO: Content {
    var id: UUID?
    var title: String
    var description: String?
    var ownerID: User.IDValue
    
    func toModel() -> Item {
        let model = Item()
        
        model.id = self.id
        model.title = self.title
        
        if let description = self.description {
            model.description = description
        }
        model.$owner.id = ownerID
        
        return model
    }
}
