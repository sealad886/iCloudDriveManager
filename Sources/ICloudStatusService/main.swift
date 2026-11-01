import Foundation

let progressRegistry = MainActor.assumeIsolated { PublishedTransferRegistry() }
let delegate = StatusServiceDelegate(progressRegistry: progressRegistry)
let listener = NSXPCListener.service()
listener.delegate = delegate
listener.resume()
