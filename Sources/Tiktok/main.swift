import Foundation

var running = true

Tiktok.main()

while (running && RunLoop.current.run(mode: .default, before: Date.distantFuture)) {
    exit(0)
}
