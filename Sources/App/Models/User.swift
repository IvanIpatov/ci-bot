import Fluent
import Vapor

final class User: Model, Content {

    // Name of the table or collection.
    static let schema = "users"

    // Unique identifier for this User.
    @ID(key: .id)
    var id: UUID?

    // The User's username.
    @Field(key: "username")
    var username: String

    // Creates a new, empty User.
    init() { }

    // Creates a new User with all properties set.
    init(id: UUID? = nil, username: String) {
        self.id = id
        self.username = username
    }
}
