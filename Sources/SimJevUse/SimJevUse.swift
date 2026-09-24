import SimJevUseCLI

@main
enum SimJevUse {
    static func main() async {
        await SimJevUseCommand.main()
    }
}
