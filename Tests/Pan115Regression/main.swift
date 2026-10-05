import Foundation

var count = 0
func check(_ value: Bool, _ label: String) {
    precondition(value, "FAIL: \(label)")
    count += 1
}
let h = String(repeating: "a", count: 40)
let other = String(repeating: "b", count: 40)
check(Pan115Identity.hash("magnet:?xt=urn:btih:\(h.uppercased())") == h, "hex magnet normalization")
check(Pan115Identity.hash("") == "", "empty hash rejected")
check(Pan115Identity.hash("magnet:?xt=urn:btih:\(h)&xt=urn:btih:\(other)") == "", "conflicting hashes")
check(Pan115Identity.taskMatches(hash: h, taskHash: h.uppercased(), taskURL: ""), "exact task hash")
check(Pan115Identity.taskMatches(hash: h, taskHash: "", taskURL: "magnet:?xt=urn:btih:\(h)"), "exact task URL")
check(!Pan115Identity.taskMatches(hash: "", taskHash: "", taskURL: "anything"), "empty contains bug")
check(!Pan115Identity.taskMatches(hash: h, taskHash: other, taskURL: "magnet:?xt=urn:btih:\(h)"), "conflicting task evidence")
check(!Pan115Identity.taskMatches(hash: h, taskHash: String(h.prefix(8)), taskURL: ""), "hash prefix unsafe")
check(!Pan115Identity.taskMatches(hash: h, taskHash: other, taskURL: "https://x/\(h)"), "substring URL unsafe")
let title = "Studio.24.05.01.Alice.Bob.Scene"
check(!Pan115Identity.strictName("Studio.24.05.01.Other.Person.mp4", title: title), "same studio and date wrong scene")
check(!Pan115Identity.strictName("Stu.24.05.01.mp4", title: title), "studio abbreviation date unsafe")
check(!Pan115Identity.strictName("Studio.Anything.mp4", title: "Studio"), "zero numeric tokens false positive")
check(!Pan115Identity.strictName("Studio.24.05.01.mp4", title: "Studio.24.05.01"), "date-only identity unsafe")
check(Pan115Identity.strictName("Studio.24.05.01.Alice.Bob.Scene.1080p.mp4", title: title), "full scene with quality suffix")
check(!Pan115Identity.strictName("Studio.24.05.01.Alice.Bob.Scene.Sample.mp4", title: title), "sample not main movie")
check(Pan115Identity.strictName("ABC-123.mp4", title: "ABC-123"), "exact code")
check(Pan115Identity.strictName("ABC123.mp4", title: "ABC123") == false, "unseparated code intentionally unsupported")
check(!Pan115Identity.strictName("ABC-1234.mp4", title: "ABC-123"), "code prefix collision")
check(Pan115Identity.manifestMatch("movie.mp4", manifest: ["folder/movie.mp4"]), "exact manifest basename in bound task")
check(!Pan115Identity.manifestMatch("movie.mp4", manifest: ["a/movie.mp4", "b/movie.mp4"]), "ambiguous manifest basename")
check(!Pan115Identity.manifestMatch("unrelated.mp4", manifest: ["movie.mp4"]), "unrelated latest file")
check(!Pan115Identity.strictName("movie.mp4", title: title), "generic manifest cannot bind global hit")
print("PASS: \(count) production 115 identity regression assertions")
