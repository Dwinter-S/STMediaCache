//
//  MediaCacheProcessor.swift
//  AVPlayerCacheDemo
//
//  Created by Mac mini on 2023/4/13.
//

import Foundation

class MediaCacheProcessor {
    let url: URL
    let cachedFileURL: URL
    let cachedFileInfo: CachedFileInfo

    private var fileManager = FileManager.default
    private var writeFileHandle: FileHandle?
    private var readFileHandle: FileHandle?
    private lazy var ioQueue: DispatchQueue = {
        return DispatchQueue(label: "com.dwinters.CachingPlayerItem.MediaCache.ioQueue.\(url.absoluteString.md5)")
    }()

    init(url: URL) {
        self.url = url
        self.cachedFileURL = MediaCache.default.cachedFileURLWith(url: url)
        let cachedFileInfoURL = MediaCache.default.cachedFileInfoURLWith(url: url)
        if fileManager.fileExists(atPath: cachedFileInfoURL.path),
           let data = fileManager.contents(atPath: cachedFileInfoURL.path),
           let value = try? JSONDecoder().decode(CachedFileInfo.self, from: data) {
            self.cachedFileInfo = value
            print("获取本地缓存文件配置:\(value.cachedFragments)")
        } else {
            self.cachedFileInfo = CachedFileInfo(url: url)
        }
    }

    func cacheData(_ data: Data, for range: NSRange, completion handler: ((Bool)->())? = nil) {
        print("STCachingPlayerItem:开始缓存：\(range)")
        guard data.count > 0, range.isValid else {
            handler?(false)
            return
        }
        MediaCache.default.createCacheDirectoryIfNeeded()
        if !fileManager.fileExists(atPath: cachedFileURL.path) {
            fileManager.createFile(atPath: cachedFileURL.path, contents: nil)
        }
        do {
            if writeFileHandle == nil {
                writeFileHandle = try FileHandle(forWritingTo: cachedFileURL)
            }
            ioQueue.async {
                self.writeFileHandle?.seek(toFileOffset: UInt64(range.location))
                self.writeFileHandle?.write(data)
                self.cachedFileInfo.addCacheFragment(range)
                print("STCachingPlayerItem:缓存成功：\(range)")
                handler?(true)
            }
        } catch {
            handler?(false)
        }
    }

    func cachedDataFor(range: NSRange, completion handler: @escaping ((Data?)->())) {
        if !fileManager.fileExists(atPath: cachedFileURL.path) {
            handler(nil)
            return
        }
        do {
            if readFileHandle == nil {
                readFileHandle = try FileHandle(forReadingFrom: cachedFileURL)
            }
            ioQueue.async {
                self.readFileHandle?.seek(toFileOffset: UInt64(range.location))
                let data = self.readFileHandle?.readData(ofLength: range.length)
                handler(data)
            }
        } catch {
            handler(nil)
        }
    }

    func setContentInfo(_ contentInfo: ContentInfo) {
        cachedFileInfo.contentInfo = contentInfo
        ioQueue.async {
            self.writeFileHandle?.truncateFile(atOffset: UInt64(contentInfo.contentLength))
            self.writeFileHandle?.synchronizeFile()
        }
    }

    func startWritting() {

    }

    func finishWritting() {

    }

    func save() {
        ioQueue.async {
            self.writeFileHandle?.synchronizeFile()
            self.cachedFileInfo.save()
        }
    }
}


//class MediaCacheProcessor: NSObject {
//    let url: URL
//    let cachedFileURL: URL
//    let cachedFileInfo: CachedFileInfo
//
//    private var fileManager = FileManager.default
//    private var inputStream: InputStream?
//    private var outputStream: OutputStream?
////    private var writeFileHandle: FileHandle?
////    private var readFileHandle: FileHandle?
//    private lazy var ioQueue: DispatchQueue = {
//        return DispatchQueue(label: "com.dwinters.CachingPlayerItem.MediaCache.ioQueue.\(url.absoluteString.md5)")
//    }()
//
//    init(url: URL) {
//        self.url = url
//        self.cachedFileURL = MediaCache.default.cachedFileURLWith(url: url)
//        let cachedFileInfoURL = MediaCache.default.cachedFileInfoURLWith(url: url)
//        if fileManager.fileExists(atPath: cachedFileInfoURL.path),
//           let data = fileManager.contents(atPath: cachedFileInfoURL.path),
//           let value = try? JSONDecoder().decode(CachedFileInfo.self, from: data) {
//            self.cachedFileInfo = value
//            print("获取本地缓存文件配置:\(value.cachedFragments)")
//        } else {
//            self.cachedFileInfo = CachedFileInfo(url: url)
//        }
//        super.init()
//    }
//
//    func cacheData(_ data: Data, for range: NSRange, completion handler: ((Bool)->())? = nil) {
//        print("STCachingPlayerItem:开始缓存：\(range)")
//        guard data.count > 0, range.isValid else {
//            handler?(false)
//            return
//        }
//        MediaCache.default.createCacheDirectoryIfNeeded()
//        if !fileManager.fileExists(atPath: cachedFileURL.path) {
//            fileManager.createFile(atPath: cachedFileURL.path, contents: nil)
//        }
//        if outputStream == nil {
//            outputStream = OutputStream(url: cachedFileURL, append: false)
//        }
//        outputStream?.delegate = self
//        outputStream?.schedule(in: .current, forMode: .common)
//        outputStream?.open()
////        do {
////            if writeFileHandle == nil {
////                writeFileHandle = try FileHandle(forWritingTo: cachedFileURL)
////            }
////            ioQueue.async {
////                self.writeFileHandle?.seek(toFileOffset: UInt64(range.location))
////                self.writeFileHandle?.write(data)
////                self.cachedFileInfo.addCacheFragment(range)
////                print("STCachingPlayerItem:缓存成功：\(range)")
////                handler?(true)
////            }
////        } catch {
////            handler?(false)
////        }
//    }
//
//    func cachedDataFor(range: NSRange, completion handler: @escaping ((Data?)->())) {
//        if !fileManager.fileExists(atPath: cachedFileURL.path) {
//            handler(nil)
//            return
//        }
//        if inputStream == nil {
//            inputStream = InputStream(url: cachedFileURL)
//        }
//        inputStream?.delegate = self
//        inputStream?.schedule(in: .current, forMode: .common)
//        inputStream?.open()
////            ioQueue.async {
////                self.readFileHandle?.seek(toFileOffset: UInt64(range.location))
////                let data = self.readFileHandle?.readData(ofLength: range.length)
////                handler(data)
////            }
//    }
//
//    func setContentInfo(_ contentInfo: ContentInfo) {
//        cachedFileInfo.contentInfo = contentInfo
//        ioQueue.async {
////            self.writeFileHandle?.truncateFile(atOffset: UInt64(contentInfo.contentLength))
////            self.writeFileHandle?.synchronizeFile()
//        }
//    }
//
//    func startWritting() {
//
//    }
//
//    func finishWritting() {
//
//    }
//
//    func save() {
//        ioQueue.async {
////            self.writeFileHandle?.synchronizeFile()
////            self.cachedFileInfo.save()
//        }
//    }
//}
//
//extension MediaCacheProcessor: StreamDelegate {
//    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
//        switch eventCode {
//        case .openCompleted:
//            print("流对象被打开")
//        case .hasBytesAvailable:
//            let maxLength = 512 * 1024
//            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: maxLength)
//            inputStream?.read(buffer, maxLength: maxLength)
//            buffer.deallocate()
//            buffer.deinitialize(count: maxLength)
//            print("开始读")
//        case .hasSpaceAvailable:
//            let maxLength = 512 * 1024
//            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: maxLength)
//            outputStream?.write(buffer, maxLength: maxLength)
//            buffer.deallocate()
//            buffer.deinitialize(count: maxLength)
//            print("开始写")
//        case .errorOccurred:
//            aStream.close()
//            aStream.remove(from: .current, forMode: .common)
//            print("读写流失败")
//        case .endEncountered:
//            print("endEncountered")
//        default: ()
//        }
//    }
//}
