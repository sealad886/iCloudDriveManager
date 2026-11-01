import Foundation

/// Read-only observations of progress published by macOS and provider backlog
/// counters. This interface exposes no cancellation or command parameters.
@objc public protocol SystemTransfersReading: ICloudStatusReading {
    func readPublishedTransfers(reply: @escaping (Data?, String?) -> Void)
    func readBacklog(reply: @escaping (Data?, String?) -> Void)
}
