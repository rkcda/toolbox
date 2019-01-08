import Vapor
import Globals
import Leaf

let swiftToolsVersionDefault = "4.0"
struct Manifest: Content {
    struct Dependency: Content {
        let gitUrl: String
        let version: String
        let importTargets: [String]
        let comment: String?
    }

    let swiftToolsVersion: String
    let packageName: String
    let dependencies: [Dependency]

    init(
        swiftToolsVersion: String,
        packageName: String = "VaporApp",
        dependencies: [Dependency]
    ) {
        self.swiftToolsVersion = swiftToolsVersion
        self.packageName = packageName
        self.dependencies = dependencies
    }
}

let dependencyTree: [String: Manifest.Dependency] = [
    "vapor": .init(
        gitUrl: "https://github.com/vapor/vapor.git",
        version: "3.0.0",
        importTargets: ["Vapor"],
        comment: "💧 a server-side Swift web framework."
    ),
    "leaf": .init(
        gitUrl: "https://github.com/vapor/leaf.git",
        version: "3.0.0",
        importTargets: ["leaf"],
        comment: "🍃 a templating language built in swift."
    )
]



let vaporDependency = NewProjectConfig.Dependency(
    gitUrl: "https://github.com/vapor/vapor.git",
    version: "3.0.0",
    includes: ["Vapor", "TesterLongName"],
    comment: "💧 A server-side Swift web framework."
)

let leafDependency = NewProjectConfig.Dependency(
    gitUrl: "https://github.com/vapor/leaf.git",
    version: "3.0.0",
    includes: ["Leaf"],
    comment: "a templating engine"
)

struct NewProjectConfig: Content {
    struct Dependency: Content {
        let gitUrl: String
        let version: String
        let comment: String?

        // the names to include as dependencies, for example ["FluentSQLite"]
        // usually one name, but possible to have dependency w/ multiple
        // libraries
        let includes: [String]

        private(set) var package: String

        init(gitUrl: String, version: String, includes: [String], comment: String? = nil) {
            self.gitUrl = gitUrl
            self.version = version
            self.includes = includes
            self.comment = comment

            self.package = ".package(url: " + gitUrl + ", from: " + version + ")"
        }
//        func _package() -> String {
//            var generated = ""
//            if let comment = comment {
//                generated += "// " + comment + "\n"
//            }
//            generated += ".package(url: " + gitUrl + ", from: " + version + "),"
//            return generated
//        }
    }

    var swiftVersion = "4.1"
    var dependencies: [Dependency] = [vaporDependency, leafDependency]
}

// TODO: Xcode Additions
// automatically add xcconfig
// swift package generate-xcodeproj --xcconfig-overrides Sandbox.xcconfig
//
// automatically add environment variables to project file, more work,
// but would be nice
//
//
// Generates an Xcode project
struct LeafXcodeCommand: Command {
    /// See `Command`.
    var arguments: [CommandArgument] = []

    /// See `Command`.
    var options: [CommandOption] = []

    /// See `Command`.
    var help: [String] = ["generates xcode projects for spm packages."]

    /// See `Command`.
    func _run(using ctx: CommandContext) throws -> Future<Void> {
        let mani = try buildManifest(with: ctx)
//        let deps = try dependencies(with: ctx)
            return try testPackageSwiftLoad(ctx: ctx)
        ctx.console.output("loading leaf file")
        let file = try Shell.readFile(path: "~/Desktop/test-leaf-file.swift")

        let config = LeafConfig(tags: .default(), viewsDir: "./", shouldCache: false)
        let renderer = LeafRenderer(config: config, using: ctx.container)
        let data = Data(bytes: file.utf8)
        let rendered = renderer.render(template: data, ["name": "context"])
        return rendered.map { view in
            print(view)
            let str = String(bytes: view.data, encoding: .utf8)
            print(str)
            ctx.console.output("got file:")
            ctx.console.output(file.consoleText())
        }
//        return .done(on: ctx.container)

//        ctx.console.output("generating xcodeproj...")
//        let generateProcess = Process.asyncExecute(
//            "swift",
//            ["package", "generate-xcodeproj"],
//            on: ctx.container
//        ) { output in
//            switch output {
//            case .stderr(let err):
//                let str = String(bytes: err, encoding: .utf8) ?? "error"
//                ctx.console.output("error:", style: .error, newLine: true)
//                ctx.console.output(str, style: .error, newLine: false)
//            case .stdout(let out):
//                let str = String(bytes: out, encoding: .utf8) ?? ""
//                ctx.console.output(str.consoleText(), newLine: false)
//            }
//        }
//
//        return generateProcess.map { val in
//            if val == 0 {
//                ctx.console.output(
//                    "success.",
//                    style: .info,
//                    newLine: true
//                )
//                try Shell.bash("open *.xcodeproj")
//            } else {
//                ctx.console.output(
//                    "failed to generate xcodeproj.",
//                    style: .error,
//                    newLine: true
//                )
//            }
//        }
    }

    /// See `Command`.
    func run(using ctx: CommandContext) throws -> Future<Void> {
        let mani = try buildManifest(with: ctx)
        try clone(
            gitUrl: "https://github.com/loganwright/vapor-template",
            name: mani.packageName,
            ctx: ctx
        )

        let manifestPath = "./\(mani.packageName)/Package.swift"

        // clone git repo
        // run leaf processor on ./clone-to-name/Package.swift
        // should be able to build this project and deploy it to vapor cloud, as is
//        let clone =
        let file = try Shell.readFile(path: manifestPath)

        let config = LeafConfig(tags: .default(), viewsDir: "./", shouldCache: false)
        let renderer = LeafRenderer(config: config, using: ctx.container)
        let data = Data(bytes: file.utf8)
        let rendered = renderer.render(template: data, mani)
        return rendered.map { view in
            let str = String(bytes: view.data, encoding: .utf8)!.replacingOccurrences(of: "\"", with: "\\\"")
            // TODO: Do w/ file manager more safely
            try Shell.bash("rm -rf \(manifestPath)")
            try Shell.bash("echo \"\(str)\" >> \(manifestPath)")
            print(str)
            ctx.console.output("got file:")
            ctx.console.output(file.consoleText())
        }
    }

    func clone(gitUrl: String, name: String, ctx: CommandContext) throws {
        // Cloning
        ctx.console.pushEphemeral()
        ctx.console.output("cloning `\(gitUrl)`...".consoleText())
        let _ = try Git.clone(repo: gitUrl, toFolder: name)
        ctx.console.popEphemeral()
        ctx.console.output("cloned `\(gitUrl)`.".consoleText())

        // used to work on a git repository
        // outside of current path
        let gitDir = "./\(name)/.git"
        let workTree = "./\(name)"

        // Prioritize tag over branch
        let checkout = ctx.options["tag"] ?? ctx.options["branch"]
        if let checkout = checkout {
            let _ = try Git.checkout(
                gitDir: gitDir,
                workTree: workTree,
                checkout: checkout
            )
            ctx.console.output("checked out `\(checkout)`.".consoleText())
        }

        // clear existing git history
        try Shell.delete("./\(name)/.git")
        let _ = try Git.create(gitDir: gitDir)
        ctx.console.output("created git repository.")

        // initialize
        try Git.commit(
            gitDir: gitDir,
            workTree: workTree,
            msg: "created new vapor project from template `\(gitUrl)`"
        )
        ctx.console.output("initialized project.")
    }


    private func buildManifest(with ctx: CommandContext) throws -> Manifest {
        let name = ctx.console.ask("project name")
        var tools = ctx.console.ask(
            "which swift tools version? (press enter to use \(swiftToolsVersionDefault))".consoleText()
        )
        if tools.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            tools = swiftToolsVersionDefault
        }

        // load dependencies
//        let deps =  try dependencies(with: ctx)
        return Manifest(
            swiftToolsVersion: tools,
            packageName: name,
            dependencies: []
        )
    }

    private func dependencies(with ctx: CommandContext) throws -> [Manifest.Dependency] {
        let done = "done"
        var all = dependencyTree.keys.sorted { $0 < $1 }
        all.append(done)

        var choices = [String]()
        while all.count > 0 {
            let choice = ctx.console.choose("add dependencies?", from: all)
            all.removeAll { $0 == choice}
            if choice == done { break }
            choices.append(choice)
        }

        return choices.compactMap { dependencyTree[$0] }
    }
}

func testPackageSwiftLoad(ctx: CommandContext) throws -> Future<Void> {
    let file = try Shell.readFile(path: "~/Desktop/delete-me/Package.swift")

    let config = LeafConfig(tags: .default(), viewsDir: "./", shouldCache: false)
    let renderer = LeafRenderer(config: config, using: ctx.container)
    let data = Data(bytes: file.utf8)
    let newProjectConfig = NewProjectConfig()
    let rendered = renderer.render(template: data, newProjectConfig)
//    let rendered = renderer.render(template: data, ["packages": ["context", "foo", "bar"]])
    return rendered.map { view in
        print(view)
        let str = String(bytes: view.data, encoding: .utf8)
        print(str!)
        ctx.console.output("got file:")
        ctx.console.output(file.consoleText())
    }
}
