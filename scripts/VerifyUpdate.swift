import Foundation
import CryptoKit

guard CommandLine.arguments.count == 4 else { fatalError("Usage: verify-update PUBLIC_KEY_FILE SIGNATURE ARCHIVE") }
let publicText = try String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
guard let publicData = Data(base64Encoded: publicText), let signature = Data(base64Encoded: CommandLine.arguments[2]) else {
    fatalError("Invalid update key or signature encoding")
}
let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicData)
let archive = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[3]), options: .mappedIfSafe)
guard publicKey.isValidSignature(signature, for: archive) else {
    fatalError("Signing key does not match the public key embedded in Ambience. Release blocked.")
}
print("Update signature verified against the app's public key.")
