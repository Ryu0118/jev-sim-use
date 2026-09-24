extension UISnapshot {
    /// The element with alias `@alias`, if this reading has it.
    func entry(alias: Int) -> UIEntry? {
        entries?.first { $0.aliases.alias == alias }
    }
}
