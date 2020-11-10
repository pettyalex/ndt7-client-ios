//
//  NDT7Settings.swift
//  NDT7
//
//  Created by NietoGuillen, Miguel on 4/18/19.
//  Copyright © 2019 M-Lab. All rights reserved.
//

import Foundation

/// Settings needed for NDT7.
/// Can be used with default values: NDT7Settings()
public struct NDT7Settings {
    public var allServers: [NDT7ServerV2]
    
    public var currentServerIndex: Int
    
    /// Configured URL to run downlaod test against
    public var downloadUrl: String
    
    /// Configured URL to run upload test against
    public var uploadUrl: String
    
    /// Hostname of configured NDT7 server
    public var hostname: String

    /// Timeouts
    public let timeout: NDT7Timeouts

    /// Skipt TLS certificate verification.
    public let skipTLSCertificateVerification: Bool

    /// Define all the headers needed for NDT7 request.
    public let headers: [String: String]

    /// Initialization.
    public init(timeout: NDT7Timeouts = NDT7Timeouts(),
                skipTLSCertificateVerification: Bool = true,
                headers: [String: String] = [NDT7WebSocketConstants.Request.headerProtocolKey: NDT7WebSocketConstants.Request.headerProtocolValue]) {
        self.skipTLSCertificateVerification = skipTLSCertificateVerification
        self.currentServerIndex = 0
        self.allServers = []
        self.timeout = timeout
        self.headers = headers
        self.hostname = ""
        self.downloadUrl = ""
        self.uploadUrl = ""
    }
}

/// Timeout settings.
public struct NDT7Timeouts {

    /// Define the interval between messages.
    /// When downloading, the server is expected to send measurement to the client,
    /// and when uploading, conversely, the client is expected to send measurements to the server.
    /// Measurements SHOULD NOT be sent more frequently than every 250 ms
    /// This parameter deine the frequent to send messages.
    /// If it is initialize with less than 250 ms, it's going to be overwritten to 250 ms
    public let measurement: TimeInterval

    /// ioTimeout is the timeout in seconds for I/O operations.
    public let ioTimeout: TimeInterval

    /// Define the max among of time used for a download test before to force to finish.
    public let downloadTimeout: TimeInterval

    /// Define the max among of time used for a upload test before to force to finish.
    public let uploadTimeout: TimeInterval

    /// Initialization.
    public init(measurement: TimeInterval = NDT7WebSocketConstants.Request.updateInterval,
                ioTimeout: TimeInterval = NDT7WebSocketConstants.Request.ioTimeout,
                downloadTimeout: TimeInterval = NDT7WebSocketConstants.Request.downloadTimeout,
                uploadTimeout: TimeInterval = NDT7WebSocketConstants.Request.uploadTimeout) {
        self.measurement = measurement >= NDT7WebSocketConstants.Request.updateInterval ? measurement : NDT7WebSocketConstants.Request.updateInterval
        self.ioTimeout = ioTimeout
        self.downloadTimeout = downloadTimeout
        self.uploadTimeout = uploadTimeout
    }
}

public struct LocateAPIV2Response: Codable {
    public var results: [NDT7ServerV2]
}

/// Response type for the new, Locate API V2 response
public struct NDT7ServerV2: Codable {
    public var machine: String
    
    public var location: NDT7Location
    
    public var urls: NDT7LocationUrls
}

public struct NDT7Location: Codable {
    public var city: String
    
    public var country: String
}

/// Upload and download URLs for the V2 Location API
public struct NDT7LocationUrls: Codable {
    public var downloadUrl: String
    
    public var uploadUrl: String
    
    public var insecureDownloadUrl: String
    
    public var insecureUploadUrl: String
    
    enum CodingKeys: String, CodingKey {
        case downloadUrl = "wss:///ndt/v7/download"
        case uploadUrl = "wss:///ndt/v7/upload"
        case insecureDownloadUrl = "ws:///ndt/v7/download"
        case insecureUploadUrl = "ws:///ndt/v7/upload"
    }
}

extension NDT7ServerV2 {
    
    /// Calls the Location V2 API to find the M-Labs recommended servers to call.
    /// These servers have on them authenticated URLs to call
    /// - parameter session: URLSession object used to request servers, using URLSession.shared object as default session.
    /// - parameter completion: callback to get the NDT7Server and error message.
    /// - parameter server: An array of NDT7ServerV2 object representing the Mlab servers available to call.
    /// - parameter error: if any error happens, this parameter returns the error.
    public static func discoverV2<T: URLSessionNDT7>(session: T = URLSession.shared as! T,
                                                     _ completion: @escaping (_ server: [NDT7ServerV2]?, _ error: NSError?) -> Void) -> URLSessionTaskNDT7 {
        let request = Networking.urlRequest(NDT7WebSocketConstants.MlabServerDiscover.urlv2)
        let task = session.dataTask(with: request) { (data, _, error) -> Void in
            OperationQueue.current?.name = "net.measurementlab.NDT7.MLabServer.discoverv2"
            
            guard error?.localizedDescription != "cancelled" else {
                completion(nil, NDT7TestConstants.cancelledError)
                return
            }
            
            guard error == nil, let data = data else {
                // Failure during network call, or null response
                completion(nil, NDT7WebSocketConstants.MlabServerDiscover.noMlabServerError)
                return
            }
            
            if let apiResponse = try? JSONDecoder().decode(LocateAPIV2Response.self, from: data) {
                completion(apiResponse.results, nil)
                return
            } else {
                // Is this the right error?
                completion(nil, NDT7WebSocketConstants.MlabServerDiscover.noMlabServerError)
                return
            }
        }
        
        task.resume()
        return task
    }
}
