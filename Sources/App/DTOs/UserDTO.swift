import Fluent
import Vapor

struct UserDTO: Content {
    var id: UUID?
    var fullName: String
    var email: String
    var isActive: Bool
    var isSuperuser: Bool
    
    func toModel() -> User {
        let model = User()
        
        model.id = self.id
        model.fullName = self.fullName
        model.email = self.email
        model.isActive = self.isActive
        model.isSuperuser = self.isSuperuser
        
        return model
    }
}
