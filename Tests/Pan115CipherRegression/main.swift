import Foundation
let payload = Data(#"{"pickcode":"test-fixture","user_id":"0"}"#.utf8)
let expected = "hisTm/0YMUOoas0CeEw6ebsixl7TMddrgRDc9+Ccu1BJlm8o/0sfaa732I7eRbtlKW7sLsQh8yvSyvR6kuDUevBUeOu9ZdNyifTLlu3gSDr1TWQmG9zqkkrVDt8U0vq9Vd/HSVxNjnW8IrGOAFv+u0yYwbTCivnUaRgOB+P2HhA="
let actual = try Pan115DownloadCipher.encrypt(payload)
precondition(actual == expected)
let zero = try Pan115DownloadCipher.transform(Array(repeating: 0, count: 128))
precondition(zero == Array(repeating: 0, count: 128))
let one = try Pan115DownloadCipher.transform(Array(repeating: 0, count: 127) + [1])
precondition(one == Array(repeating: 0, count: 127) + [1])
for malformed in ["", "!", "AA=="] {
    do { _ = try Pan115DownloadCipher.decrypt(malformed); fatalError("accepted malformed cipher") }
    catch { }
}
let data = Array(payload)
precondition(Pan115DownloadCipher.xor(Pan115DownloadCipher.xor(data, [1,2,3,4]), [1,2,3,4]) == data)
print("PASS: real RSA known vector, raw modular transform, XOR roundtrip, malformed decrypt")
