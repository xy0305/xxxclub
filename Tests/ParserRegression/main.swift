import Foundation

func require(_ condition: Bool, _ message: String) {
    guard condition else { fatalError(message) }
}
let imageTag = "<img src='https://imgxclub.com/ps/test.jpeg' class='floaterimg'>"
require(HTML.first(imageTag, pattern: "<img\\b[^>]*floaterimg[^>]*>") == imageTag,
        "Whole-tag regex must return the full match without a capture group")
require(HTML.first("src='value'", pattern: "src=['\"]([^'\"]+)['\"]") == "value",
        "Capture-group callers must remain unchanged")
let fixture = """
<li><a href='/torrents/details/test-1'>Example Film One 2160p</a>
\(imageTag)<span class='siz'>2 GB</span></li>
<li><a href='/torrents/details/test-2'>Example Film Two 1080p</a>
<img class="floaterimg" src="https://imgxclub.com/ps/test2.jpeg"></li>
"""
let items = XCParser.parseRows(fixture)
require(items.count == 2, "Synthetic fixture must have two rows")
require(items[0].coverURL?.absoluteString == "https://imgxclub.com/p/test.jpeg", "Row one cover missing")
require(items[1].coverURL?.absoluteString == "https://imgxclub.com/p/test2.jpeg", "Row two cover missing")
print("PASS: whole-tag helper, capture helper, both image attribute orders")
for path in CommandLine.arguments.dropFirst() {
    let html = try String(contentsOfFile: path, encoding: .utf8)
    let rows = XCParser.parseRows(html)
    require(!rows.isEmpty, "No rows in \(path)")
    let missing = rows.filter { $0.coverURL == nil }
    require(missing.isEmpty, "Missing covers in \(path): \(missing.map(\.id))")
    print("PASS: \(path): \(rows.count) rows, all covers present")
}
