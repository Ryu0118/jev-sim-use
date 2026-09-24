import SimJevUseKit

@main
struct SimJevUseMain {
    static func main() {
        if CommandLine.arguments.dropFirst().contains("--version") {
            print(SimJevUseVersion.current)
            return
        }
        print(SimJevUseKit.greeting())
    }
}
