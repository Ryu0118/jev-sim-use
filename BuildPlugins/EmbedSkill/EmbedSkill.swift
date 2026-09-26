import Foundation
import PackagePlugin

/// Embeds skills/jev-sim-use into the target as `SkillBundle.files`, because releases ship the executable alone (no
/// resource bundle). Every Markdown file is an input, so editing one rebuilds the embed; the list itself is read on
/// every build, so an added or removed reference is picked up too.
@main
struct EmbedSkill: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target _: Target) async throws -> [Command] {
        let skill = context.package.directoryURL.appending(path: "skills/jev-sim-use")
        let references = try FileManager.default.contentsOfDirectory(atPath: skill.appending(path: "references").path())
            .filter { $0.hasSuffix(".md") }.sorted().map { "references/\($0)" }
        let files = ["SKILL.md"] + references
        let output = context.pluginWorkDirectoryURL.appending(path: "SkillBundle+Files.swift")
        return try [
            .buildCommand(
                displayName: "Embedding skills/jev-sim-use",
                executable: context.tool(named: "EmbedSkillTool").url,
                arguments: [output.path(), skill.path()] + files,
                inputFiles: files.map { skill.appending(path: $0) },
                outputFiles: [output],
            ),
        ]
    }
}
