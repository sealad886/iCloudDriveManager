import Foundation

let delegate = StatusServiceDelegate()
let listener = NSXPCListener.service()
listener.delegate = delegate
listener.resume()
