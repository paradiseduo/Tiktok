import ArgumentParser
import Foundation
import IndexStoreDB

let version = "1.0.0"

let threadGroup = DispatchGroup()
let queue = DispatchQueue(label: "com.tiktok", qos: .userInteractive, attributes: [.concurrent], autoreleaseFrequency: .inherit, target: nil)

struct Tiktok: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Tiktok v\(version)", discussion: "tiktok is a tool which scan indexDB AST to find api which one used.", version: version)
    
    @Argument(help: "The indexDB path for Tiktok.")
    var indexDBPath: String
    
    @Argument(help: "The api json file path for Tiktok.")
    var apiPath: String
    
    @Argument(help: "The output path for Tiktok.")
    var outPutPath: String
    
    mutating func run() throws {
        if indexDBPath.count == 0 {
            Log.writeMessage("indexDB path can not be nil!", .error)
            running = false
        }
        
        if apiPath.count == 0 {
            Log.writeMessage("api json file path can not be nil!", .error)
            running = false
        }
        
        if FileManager.default.fileExists(atPath: indexDBPath) == false {
            Log.writeMessage("indexDB not exist!", .error)
            running = false
        }
        
        if FileManager.default.fileExists(atPath: apiPath) == false || !apiPath.hasSuffix(".json") {
            Log.writeMessage("api json file not exist!", .error)
            running = false
        }
        
        do {
            if !FileManager.default.fileExists(atPath: outPutPath) {
                try FileManager.default.createDirectory(atPath: outPutPath, withIntermediateDirectories: true)
            }
            
            let workspace = Workspace.init(indexStorePath: indexDBPath)
            
            
            if let data = FileManager.default.contents(atPath: apiPath) {
                let apis = try JSONDecoder().decode(Apis.self, from: data)
                for api in apis.apis {
                    threadGroup.enter()
                    var outPath = ""
                    if FileManager.default.fileExists(atPath: outPutPath) {
                        var jsonName = "/\(api.className).\(api.apiName.replacingOccurrences(of: "[^A-Za-z0-9:]+", with: "", options: [.regularExpression]))"
                        if jsonName.count > 250 {
                            jsonName = String(jsonName.prefix(250))
                        }
                        outPath = self.outPutPath+jsonName+".json"
                    }
                    DispatchLimitQueue.shared.limit(queue: queue, group: threadGroup, count: ProcessInfo.processInfo.activeProcessorCount/2) {
                        do {
                            let startSymbols = workspace.start(className: api.className, funcName: api.apiName)
                            var node = Node.init(usr: api.className, name: api.apiName, path: "", line: "", module: "", children: [Node]())
                            var step = Step()
                            workspace.covert(arr: startSymbols, node: &node, step: &step)
                            
                            let json = JSONEncoder()
                            json.outputFormatting = .prettyPrinted
                            let jsonData = try json.encode(node)
                            let jsonString = String(decoding: jsonData, as: UTF8.self)
                            if outPath == "" {
                                Log.writeMessage("\(jsonString)")
                            } else {
                                try jsonString.write(toFile: outPath, atomically: true, encoding: String.Encoding.utf8)
                            }
                            threadGroup.leave()
                        } catch {
                            Log.writeMessage(error.localizedDescription, .error)
                            threadGroup.leave()
                        }
                    }
                }
                threadGroup.wait()
                threadGroup.notify(qos: DispatchQoS.userInteractive, flags: DispatchWorkItemFlags.barrier, queue: DispatchQueue.main) {
                    running = false
                }
                
            } else {
                Log.writeMessage("api json file is empty!", .error)
                running = false
            }
        } catch {
            Log.writeMessage(error.localizedDescription, .error)
            running = false
        }
    }
}

class DispatchLimitQueue {
    static let shared = DispatchLimitQueue()
    private var receiveQueues = [String: DispatchQueue]()
    private var limitSemaphores = [String: DispatchSemaphore]()
    
    func limit(queue: DispatchQueue, group: DispatchGroup? = nil, count: Int, handle: @escaping ()->()) {
        let label = "\(queue.label).limit"
        var limitSemaphore: DispatchSemaphore!
        var receiveQueue: DispatchQueue!
        if let q = receiveQueues[label], let s = limitSemaphores[label] {
            limitSemaphore = s
            receiveQueue = q
        } else {
            limitSemaphore = DispatchSemaphore(value: count)
            receiveQueue = DispatchQueue(label: label)
            limitSemaphores[label] = limitSemaphore
            receiveQueues[label] = receiveQueue
        }
        
        receiveQueue.async {
            let _ = limitSemaphore.wait(timeout: DispatchTime.distantFuture)
            queue.async(group: group) {
                defer {
                    limitSemaphore.signal()
                }
                handle()
            }
        }
    }
}
