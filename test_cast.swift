import Foundation
let anyArray: [Any]? = []
if let _ = anyArray as? [String] {
    print("Cast succeeded for empty array")
} else {
    print("Cast failed for empty array")
}
