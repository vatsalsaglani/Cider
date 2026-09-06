import Foundation
import Darwin

// Deliberately unavailable until Plan 08; never reads arguments as file/command authority.
let response = #"{"schemaVersion":1,"error":{"code":"unavailable","message":"Cider TODO access is not available in this build."}}"#
print(response)
exit(4)
