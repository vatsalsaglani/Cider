import Foundation
import Darwin

do {
    let arguments = try CLIArguments.parse(CommandLine.arguments)
    let result = try await TodoCommands.execute(arguments)
    print(try CLIOutput.success(result.data, revision: result.revision, nextCursor: result.nextCursor, truncated: result.truncated))
    exit(0)
} catch {
    fputs(CLIOutput.error(error) + "\n", stderr)
    exit(Int32(CLIOutput.exitCode(error)))
}
