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
let releaseTitle = "Naughty America.2024-05-01.Alice.Bob.Scene"
check(Pan115Identity.release(releaseTitle)?.date == "24.05.01", "title RELEASE year normalization")
check(Pan115Identity.studioDateCandidate("NA.24.05.01.Other.Actor.mp4", title: releaseTitle), "studio date is candidate not identity")
check(!Pan115Identity.safeStudioHit("NA.24.05.01.Other.Actor.mp4", title: releaseTitle, manifest: []), "same date other actors never autoplay")
check(Pan115Identity.safeStudioHit("NA.24.05.01.Alice.Bob.Scene.1080p.mp4", title: releaseTitle, manifest: []), "alias plus full distinguishing title")
check(!Pan115Identity.safeStudioHit("NA.24.05.01.mp4", title: releaseTitle, manifest: []), "single date-only candidate not proof")
check(!Pan115Identity.safeStudioHit("NA.24.05.01.mp4", title: releaseTitle, manifest: ["NA.24.05.01.mp4"]), "generic manifest cannot authorize autoplay")
check(Pan115Identity.studioDateCandidate("PornMegaLoad_24_05_01_Alice_Bob.mp4", title: "PML.2024.05.01.Alice.Bob"), "known camelcase alias")
check(Pan115Identity.studioDateCandidate("RK 2024/05/01 Alice Bob.mp4", title: "RealityKings.24.05.01.Alice.Bob"), "space slash date")
check(!Pan115Identity.studioDateCandidate("NA.24.05.02.Alice.Bob.mp4", title: releaseTitle), "different date rejected")
check(!Pan115Identity.studioDateCandidate("RK.24.05.01.Alice.Bob.mp4", title: releaseTitle), "different studio rejected")
check(Pan115Identity.studioDateQueries("Studio Alice Bob").isEmpty, "no title release means no added-date substitution")
check(Pan115Identity.studioDateQueries("24.05.01").isEmpty, "missing studio no queries")
check(Pan115Identity.studioDateQueries("Studio.24.02.30.Alice.Bob").isEmpty, "invalid date rejected")
check(Pan115Identity.studioDateQueries("Studio.24.02.29.Alice.Bob").count == 2, "leap release date valid")
check(!Pan115Identity.distinguishedName("NA.24.05.01.Alice.Bob.Sample.mp4", title: "NaughtyAmerica.24.05.01.Alice.Bob"), "sample suffix blocked")
let ambiguous = ["NA.24.05.01.Alice.Bob.1080p.mp4", "NA.24.05.01.Alice.Bob.2160p.mp4"]
check(ambiguous.filter { Pan115Identity.safeStudioHit($0, title: "NaughtyAmerica.24.05.01.Alice.Bob", manifest: []) }.count == 2, "multiple valid identities preserved for manual chooser")
check(Pan115Identity.studioDateQueries("NaughtyAmerica.24.05.01.Alice.Bob").first == "naughtyamerica.24.05.01", "full studio date search first")
check(Pan115Identity.studioDateQueries("NaughtyAmerica.24.05.01.Alice.Bob").contains("na.24.05.01"), "known abbreviation searched")
let tushyTitle = "Tushy 26 10 04 Megan Longoria And Mary Rock Gorgeous Duo Anal Threesome XXX 2160p MP4-P2P [XC]"
let tushyFile = "tushy.26.10.04.megan.longoria.and.mary.rock.gorgeous.duo.anal.threesome.xxx"
check(Pan115Identity.strictName(tushyFile, title: tushyTitle), "user exact extensionless sample")
check(Pan115Identity.safeStudioHit(tushyFile + ".mp4", title: tushyTitle, manifest: []), "live 11.27GB video identity")
check(Pan115Identity.safeStudioHit(tushyFile, title: tushyTitle, manifest: ["unrelated.mp4"]), "strong scene identity independent of unrelated manifest")
check(!Pan115Identity.safeStudioHit(tushyFile.replacingOccurrences(of: "mary.rock", with: "other.actor"), title: tushyTitle, manifest: []), "same release different actors")
check(!Pan115Identity.safeStudioHit(tushyFile.replacingOccurrences(of: "gorgeous.duo", with: "different.scene"), title: tushyTitle, manifest: []), "same actors different scene")
check(!Pan115Identity.safeStudioHit(tushyFile + ".sample.mp4", title: tushyTitle, manifest: []), "sample cannot be stripped as metadata")
check(!Pan115Identity.safeStudioHit("tushy.26.10.04.mp4", title: tushyTitle, manifest: []), "date alone never autoplay")
check(Pan115Identity.semanticTokens(tushyTitle).joined(separator: ".") == String(tushyFile.dropLast(4)), "clean compact distinctive query")
let xenaTitle = "ShesInMyBed 26 10 05 Xena Dream XXX 2160p MP4-WRB [XC]"
let xenaFile = "shesinmybed.26.10.05.xena.dream.4k"
check(Pan115Identity.semanticTokens(xenaTitle) == Pan115Identity.semanticTokens(xenaFile), "WRB suffix and 4K alias normalize actual sample")
check(Pan115Identity.strictName(xenaFile, title: xenaTitle), "actual extensionless Xena file")
check(Pan115Identity.safeStudioHit(xenaFile + ".mp4", title: xenaTitle, manifest: []), "actual 2876197049 byte Xena video")
for quality in ["4k", "2160p", "1080p", "720p", "480p", "1440p", "uhd", "fhd", "8k", "4320p"] {
    check(Pan115Identity.safeStudioHit("shesinmybed.26.10.05.xena.dream.\(quality).mp4", title: xenaTitle, manifest: []), "resolution suffix \(quality)")
}
for nearMiss in ["shesinmybed.26.10.04.xena.dream.4k.mp4", "shesinmybed.26.10.05.other.actor.4k.mp4", "shesinmybed.26.10.05.xena.other.4k.mp4", "shesinmybed.26.10.05.xena.dream.sample.4k.mp4", "shesinmybed.26.10.05.4k.mp4", "shesinmybed.26.10.05.xena.dream.other.scene.4k.mp4"] {
    check(!Pan115Identity.safeStudioHit(nearMiss, title: xenaTitle, manifest: []), "Xena near miss rejected: \(nearMiss)")
}
check(Pan115Identity.semanticTokens("Studio.26.10.05.Wrb.Actor.4k.mp4").contains("wrb"), "standalone WRB actor retained")
check(Pan115Identity.semanticTokens("Studio.26.10.05.Xxx.Actor.4k.mp4").contains("xxx"), "internal technical-looking semantic word retained")
print("PASS: \(count) production 115 identity regression assertions")
