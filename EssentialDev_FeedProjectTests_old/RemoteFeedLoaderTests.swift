//
//  RemoteFeedLoaderTests.swift
//  EssentialDev_FeedProjectTests
//
//  Created by Poland, Tyler on 10/10/23.
//

import XCTest
import EssentialDev_FeedProject

final class RemoteFeedLoaderTests: XCTestCase {
    
    func test_init() {
        let client = HTTPClientSpy()
        _ = makeSUT()
        
        XCTAssertTrue(client.requestedURLs.isEmpty)
    }
    
    func test_load_requestsDataFromURL() {
        let url = URL(string: "https://a-given-url.com")!
        let (sut, client) = makeSUT(url: url)
        
        sut.load() { _ in }
        
        XCTAssertEqual(client.requestedURLs, [url])
    }
    
    func test_loadTwice_RequestsDataFromURLTwice() {
        let url = URL(string: "https://a-given-url.com")!
        let (sut, client) = makeSUT(url: url)
        
        sut.load() { _ in }
        sut.load() { _ in }
        
        XCTAssertEqual(client.requestedURLs, [url, url])
    }
    
    func test_load_deliversErrorOnClientError() {
        let (sut, client) = makeSUT()
        
		expect(sut, toCompleteWith: .failure(.connectivity)) {
            let clientError = NSError(domain: "Test", code: 0)
            client.complete(with: clientError)
        }
    }
    
    func test_load_deliversErrorOnNon200HTTPResponse() {
        let (sut, client) = makeSUT()
        let samples = [199, 201, 300, 400, 500]
        
        samples.enumerated().forEach { index, statusCode in
			expect(sut, toCompleteWith: .failure(.invalidData)) {
                client.complete(withStatusCode: statusCode, at: index)
            }
        }
    }
    
    func test_load_deliversErrorOn200HTTPResponseWithInvalidJSON() {
        let (sut, client) = makeSUT()
        
		expect(sut, toCompleteWith: .failure(.invalidData)) {
            let invalidJSON = Data("invalid json".utf8)
            client.complete(withStatusCode: 200, data: invalidJSON)
        }
    }
    
    func test_load_deliversNoItemsOn200HTTPResponseWithEmptyJSONList() {
        let (sut, client) = makeSUT()

		expect(sut, toCompleteWith: .success([])) {
			let emptyListJSON = Data("{\"items\": []}".utf8)
			client.complete(withStatusCode: 200, data: emptyListJSON)
		}
    }
	
	func test_load_deliversItemsOn200ResponseWithJSONItems() {
		let (sut, client) = makeSUT()
		
		let item1 = FeedItem(id: UUID(),
							 description: nil,
							 location: nil,
							 imageURL: URL(string: "http://a-url.com")!
		)
		let item1JSON = [
			"id": item1.id.uuidString,
			"image": item1.imageURL.absoluteString
		]
		
		let item2 = FeedItem(id: UUID(),
							 description: "a description",
							 location: "a location",
							 imageURL: URL(string: "http://another-url.com")!
		)
		let item2JSON = [
			"id": item2.id.uuidString,
			"description": item2.description,
			"location": item2.location,
			"image": item2.imageURL.absoluteString
		]
		
		let itemsJSON = [
			"items": [item1JSON, item2JSON]
		]
		
		expect(sut, toCompleteWith: .success([item1, item2])) {
			let data = try! JSONSerialization.data(withJSONObject: itemsJSON)
			client.complete(withStatusCode: 200, data: data)
		}
	}

    
    // MARK: - Helpers
    private func makeSUT(url: URL = URL(string: "https://a-given-url.com")!) -> (sut: RemoteFeedLoader, client: HTTPClientSpy) {
        let client = HTTPClientSpy()
        let sut = RemoteFeedLoader(url: url, client: client)
        return (sut, client)
    }
    
    private func expect(_ sut: RemoteFeedLoader,
                        toCompleteWith result: RemoteFeedLoader.Result,
                        when action: () -> Void,
                        file: StaticString = #filePath,
                        line: UInt = #line
    ) {
        var capturedResults = [RemoteFeedLoader.Result]()
        sut.load { result in
            capturedResults.append(result)
        }
        
        action()
        
        XCTAssertEqual(capturedResults, [result], file: file, line: line)
    }
    
    private class HTTPClientSpy: HTTPClient {
        
        private var messages = [(url: URL, completion: (HTTPClientResult) -> Void)]()
        
        var requestedURLs: [URL] {
            return messages.map { $0.url }
        }
        
        var completions: [(HTTPClientResult) -> Void] {
            return messages.map { $0.completion }
        }
        
        func get(from url: URL, completion: @escaping (HTTPClientResult) -> Void) {
            messages.append( (url, completion) )
        }
        
        func complete(with error: Error, at index: Int = 0) {
            completions[index](.failure(error))
        }
        
        func complete(withStatusCode code: Int, data: Data = Data(), at index: Int = 0) {
            let response = HTTPURLResponse(
                url: requestedURLs[index],
                statusCode: code,
                httpVersion: nil,
                headerFields: nil
            )!
            messages[index].completion(.success(data, response))
        }
        
    }
}
