//
//  LoadingTask.swift
//  AVPlayerCacheDemo
//
//  Created by Mac mini on 2023/4/12.
//

import Foundation

enum LoadingTaskType {
    case local
    case remote
}

class LoadingTask {
    let taskType: LoadingTaskType
    let range: NSRange
    
    init(taskType: LoadingTaskType, range: NSRange) {
        self.taskType = taskType
        self.range = range
    }
    
    static func == (lhs: LoadingTask, rhs: LoadingTask) -> Bool {
        return (lhs.taskType == rhs.taskType) && (lhs.range == rhs.range)
    }
}
