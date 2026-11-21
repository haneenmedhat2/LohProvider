//
//  NetworkConstants.swift
//  NewSwiftUIBase
//
//  Created by Mohamed Hadwa on 22/12/2023.
//

import Foundation


struct APIConfiguration {
    static let live = APIConfiguration(baseURL: URL(string: "https://upgrade.loh.com.sa/api/")!)

    let baseURL: URL
    var timeout: TimeInterval = 30
}

struct NetworkConstants {
    private init() {}
    static var server: String { APIConfiguration.live.baseURL.absoluteString }
}
