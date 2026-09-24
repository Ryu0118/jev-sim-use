import ArgumentParser
import JevSimUseKit

extension InputText: ExpressibleByArgument {
    /// Parses `name=value`; the value may itself contain `=`.
    public init?(argument: String) {
        guard let separator = argument.firstIndex(of: "=") else { return nil }
        let name = argument[..<separator].trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return nil }
        self.init(name: name, value: String(argument[argument.index(after: separator)...]))
    }
}
