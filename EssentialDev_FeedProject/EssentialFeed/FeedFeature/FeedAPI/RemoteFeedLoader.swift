//
//  RemoteFeedLoader.swift
//  EssentialDev_FeedProject
//
//  Created by Poland, Tyler on 10/12/23.
//

import Foundation

// MARK: - Client
public protocol HTTPClient {
    func get(from url: URL, completion: @escaping (HTTPClientResult) -> Void)
}

public enum HTTPClientResult {
    case success(Data, HTTPURLResponse)
    case failure(Error)
}

// MARK: - Loader
public final class RemoteFeedLoader {
    private let url: URL
    private let client: HTTPClient
    
    public enum Error: Swift.Error {
        case connectivity
        case invalidData
    }
    
    public enum Result: Equatable {
        case success([FeedItem])
        case failure(RemoteFeedLoader.Error)
    }
    
    public init(url: URL, client: HTTPClient) {
        self.client = client
        self.url = url
    }
    
    public func load(completion: @escaping (Result) -> Void) {
        client.get(from: url) { result in
            switch result {
			case let .success(data, response):
				do {
					let items = try FeedItemMapper.map(data, response)
					completion(.success(items))
				} catch {
					completion(.failure(.invalidData))
				}
			case .failure(_):
				completion(.failure(.connectivity))
            }
        }
    }
}

private class FeedItemMapper {
	static func map(_ data: Data, _ response: HTTPURLResponse) throws -> [FeedItem] {
		guard response.statusCode == 200 else {
			throw RemoteFeedLoader.Error.invalidData
		}
		
		return try JSONDecoder().decode(Root.self, from: data).items.map { $0.item }
	}
}

private struct Root: Decodable {
	let items: [Item]
}

private struct Item: Decodable {
	let id: UUID
	let description: String?
	let location: String?
	let image: URL
	
	var item: FeedItem {
		return FeedItem(id: id, description: description, location: location, imageURL: image)
	}
	
}


