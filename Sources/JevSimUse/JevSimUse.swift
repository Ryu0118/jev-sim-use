import JevSimUseCLI

@main
enum JevSimUse {
    static func main() async {
        await JevSimUseCommand.main()
    }
}
