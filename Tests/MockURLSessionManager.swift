//
//  MockImageDataLoader.swift
//  Nuke
//
//  Created by Alexander Grebenyuk on 3/14/15.
//  Copyright (c) 2016 Alexander Grebenyuk (github.com/kean). All rights reserved.
//

import Foundation
import Nuke

class MockImageDataLoader: ImageDataLoader {
    var enabled = true {
        didSet {
            self.queue.isSuspended = !enabled
        }
    }
    var createdTaskCount = 0
    fileprivate let queue = OperationQueue()

    override func taskWith(_ request: ImageRequest, progress: ImageDataLoadingProgress, completion: ImageDataLoadingCompletion) -> URLSessionTask {
        self.queue.addOperation {
            progress(50, 100)
            progress(100, 100)
            let bundle = Bundle(for: MockImageDataLoader.self)
            let URL = bundle.url(forResource: "Image", withExtension: "jpg")
            let data = try? Data(contentsOf: URL!)
            DispatchQueue.main.async {
                completion(data, nil, nil)
            }
        }
        self.createdTaskCount += 1
        return MockURLSessionDataTask()
    }
}
