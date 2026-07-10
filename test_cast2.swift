import Foundation
class VNObj {}
let anyArray: [Any]? = []
if let res = anyArray as? [VNObj] {
    print("Cast succeeded for empty array, count: \(res.count)")
} else {
    print("Cast failed for empty array")
}

let anyArrayNil: [Any]? = nil
if let res = anyArrayNil as? [VNObj] {
    print("Cast succeeded for nil array")
} else {
    print("Cast failed for nil array")
}
