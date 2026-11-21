//
//  NetworkExecuter.swift
//  NewSwiftUIBase
//
//  Created by Mohamed Hadwa on 22/12/2023.
//

import Foundation

protocol NetworkExecuter {
    func execute(_ request: any Requestable, progress progressHandler: ((_ progress: Int) -> Void)?) async throws -> NetworkResponse
    func execute(_ request: URLRequest) async throws -> NetworkResponse
}

struct NetworkResponse {
    let statusCode: Int
    let data: Data
}


