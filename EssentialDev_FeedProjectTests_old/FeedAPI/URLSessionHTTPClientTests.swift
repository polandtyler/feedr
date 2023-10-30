//
//  URLSessionHTTPClientTests.swift
//  EssentialDev_FeedProjectTests
//
//  Created by Poland, Tyler on 10/21/23.
//

import XCTest
import EssentialDev_FeedProject

class URLSessionHTTPClient {
	private let session: URLSession
	
	init(session: URLSession = .shared) {
		self.session = session
	}
	
	func get(from url: URL, completion: @escaping (HTTPClientResult) -> Void) {
		let url = URL(string: "http://any-url.com")!
		session.dataTask(with: url) { _, _, error in
			if let error {
				completion(.failure(error))
			}
		}.resume()
	}
}

final class URLSessionHTTPClientTests: XCTestCase {
	
	override class func setUp() {
		super.setUp()
		URLProtocolStub.startInterceptingRequests()
	}
	
	override class func tearDown() {
		URLProtocolStub.stopInterceptingRequests()
		super.tearDown()
	}
	
	func test_getFromURL_performsGETRequestWithURL() {
		
		let url = anyURL()
		
		let exp = expectation(description: "Wait for request")

		URLProtocolStub.observeRequests { request in
			XCTAssertEqual(request.url, url)
			XCTAssertEqual(request.httpMethod, "GET")
			exp.fulfill()
		}
		
		makeSUT().get(from: url) { _ in }

		wait(for: [exp], timeout: 1.0)
	}
	
	func test_getFromURL_failsOnRequestError() {
		let error = NSError(domain: "any error", code: 1, userInfo: nil)
		URLProtocolStub.stub(data: nil, response: nil, error: error)
		
		let exp = expectation(description: "Wait for completion")
		
		makeSUT().get(from: anyURL()) { result in
			switch result {
			case let .failure(receivedError as NSError):
				XCTAssertEqual(receivedError, error)
			default:
				XCTFail("Expected failure with error \(error), got \(result) instead")
			}
			
			exp.fulfill()
		}
		
		wait(for: [exp], timeout: 1.0)
	}
	
	// MARK: - TEST HELPERS
	
	private func makeSUT(file: StaticString = #file, line: UInt = #line) -> URLSessionHTTPClient {
		let sut = URLSessionHTTPClient(session: URLSession.shared)
		trackForMemoryLeaks(sut, file: file, line: line)
		return sut
	}
	
	private func anyURL() -> URL {
		return URL(string: "http://a-url.com")!
	}
	
	private class URLProtocolStub: URLProtocol {
		private static var stub: Stub?
		
		private static var requestObserver: ((URLRequest) -> Void)?
		
		private struct Stub {
			let data: Data?
			let response: URLResponse?
			let error: Error?
		}
		
		static func stub(data: Data?, response: URLResponse?, error: Error?) {
			stub = Stub(data: data, response: response, error: error)
		}
		
		static func observeRequests(observer: @escaping (URLRequest) -> Void) {
			requestObserver = observer
		}
		
		static func startInterceptingRequests() {
			URLProtocol.registerClass(URLProtocolStub.self)
		}
		
		static func stopInterceptingRequests() {
			URLProtocol.unregisterClass(URLProtocolStub.self)
			stub = nil
		}
		
		override class func canInit(with request: URLRequest) -> Bool {
			requestObserver?(request)
			return true
		}
		
		override class func canonicalRequest(for request: URLRequest) -> URLRequest {
			return request
		}
		
		override func startLoading() {
			if let data = URLProtocolStub.stub?.data {
				client?.urlProtocol(self, didLoad: data)
			}
			
			if let response = URLProtocolStub.stub?.response {
				client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
			}
			
			if let error = URLProtocolStub.stub?.error {
				client?.urlProtocol(self, didFailWithError: error)
			}
			
			client?.urlProtocolDidFinishLoading(self)
		}
		
		override func stopLoading() {}
	}

}

