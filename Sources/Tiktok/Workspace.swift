import Foundation
import IndexStoreDB

struct Node: Codable, Equatable {
    var usr: String
    var name: String
    var path: String
    var line: String
    var module: String
    var children: [Node]
    
    static func == (lhs: Node, rhs: Node) -> Bool {
        return lhs.usr == rhs.usr && lhs.name == rhs.name && lhs.path == rhs.path && lhs.line == rhs.line && lhs.module == rhs.module && lhs.children == rhs.children
    }
    
    static func != (lhs: Node, rhs: Node) -> Bool {
        return lhs.usr != rhs.usr || lhs.name != rhs.name || lhs.path != rhs.path || lhs.line != rhs.line || lhs.module != rhs.module || lhs.children != rhs.children
    }
}

struct Apis: Codable {
    var apis: [Api]
    
    struct Api: Codable {
        var apiName: String
        var className: String
    }
}

struct Step {
    private var stepover = Set<String>()
    static var unfairLock = os_unfair_lock_s()
    
    mutating func insert(_ s: String) {
        os_unfair_lock_lock(&Step.unfairLock)
        defer {
            os_unfair_lock_unlock(&Step.unfairLock)
        }
        self.stepover.insert(s)
    }
    
    func contains(_ s: String) -> Bool {
        os_unfair_lock_lock(&Step.unfairLock)
        defer {
            os_unfair_lock_unlock(&Step.unfairLock)
        }
        return self.stepover.contains(s)
    }
}



struct Workspace {
    static let libIndexStore = "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/libIndexStore.dylib"
        
    var indexStorePath: String
    
    let indexDatabasePath = NSTemporaryDirectory() + "index_\(getpid())"

    var index: IndexStoreDB?
    
    init(indexStorePath: String) {
        self.indexStorePath = indexStorePath
        
        do {
            let lib = try IndexStoreLibrary(dylibPath: Workspace.libIndexStore)
            self.index = try IndexStoreDB(storePath: URL(fileURLWithPath: self.indexStorePath).path, databasePath: self.indexDatabasePath, library: lib, waitUntilDoneInitializing: true, listenToUnitEvents: true)
            Log.writeMessage("opened IndexStoreDB at \(self.indexDatabasePath) with store path \(self.indexStorePath)")
        } catch {
            Log.writeMessage("failed to open IndexStoreDB: \(error.localizedDescription)", .error)
        }
    }
    
    func start(className: String, funcName: String) -> [SymbolOccurrence] {
        var symbolOccurrenceResults: [SymbolOccurrence] = []
        self.index?.forEachCanonicalSymbolOccurrence(containing: funcName, anchorStart: true, anchorEnd: true, subsequence: false, ignoreCase: false) { so in
            if so.symbol.usr.contains(className) {
                symbolOccurrenceResults.append(so)
            }
            return true
        }
        return symbolOccurrenceResults
    }
    
    func next(symbol: Symbol) -> [SymbolOccurrence] {
        var symbolOccurrenceResults: [SymbolOccurrence] = []
        self.index?.forEachSymbolOccurrence(byUSR: symbol.usr, roles: SymbolRole.all) { so in
            if !so.location.isSystem {
                symbolOccurrenceResults.append(so)
            }
            return true
        }
        return symbolOccurrenceResults
    }

    func covert(arr: [SymbolOccurrence], node: inout Node, step: inout Step) {
        for item in arr {
            var newNode = Node.init(usr: item.symbol.usr, name: item.symbol.name, path: item.location.path, line:"\(item.location.line)", module: item.location.moduleName, children: [Node]())
            if item.location.isSystem {
                self.covert(arr: self.next(symbol: item.symbol), node: &newNode, step: &step)
            } else {
                if item.location.path.hasSuffix(".h") {
                    continue
                }
                if !step.contains(item.description) {
                    step.insert(item.description)
                    for ii in item.relations where ii.roles.contains(.calledBy) {
                        self.covert(arr: self.next(symbol: ii.symbol), node: &newNode, step: &step)
                    }
                }
            }
            if newNode != node {
                node.children.append(newNode)
            }
        }
    }
}

