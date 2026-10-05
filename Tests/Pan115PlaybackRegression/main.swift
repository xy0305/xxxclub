import Foundation

var count = 0
func check(_ value: Bool, _ label: String) {
    precondition(value, "FAIL: \(label)")
    count += 1
}
check(Pan115PlaybackRouting.originalURL(["data": ["url": ["url": "https://cdn.example/movie.mkv?sign=test"]]])?.path == "/movie.mkv", "download nested URL")
check(Pan115PlaybackRouting.originalURL(["download_url": "https://cdn.example/movie.mp4"]) != nil, "explicit source")
check(Pan115PlaybackRouting.originalURL(["video_url": "https://cdn.example/video.mp4"]) == nil, "video field not source proof")
check(Pan115PlaybackRouting.originalURL(["download_url": "https://cdn.example/master.m3u8?sign=test"]) == nil, "HLS never source")
check(Pan115PlaybackRouting.originalURL(["state": false, "download_url": "https://cdn.example/movie.mp4"]) == nil, "failed response rejected")
check(Pan115PlaybackRouting.directURL("file:///tmp/movie.mp4") == nil, "local URL rejected")
let common = ["Cookie": "dummy=test", "Referer": "https://115.com/", "User-Agent": "test-agent"]
let cdn = Pan115PlaybackRouting.headers(url: URL(string: "https://cdn.example/movie.mp4")!, common: common)
check(cdn["Cookie"] == nil, "no credential leak to CDN")
check(cdn["Referer"] == common["Referer"] && cdn["User-Agent"] == common["User-Agent"], "retain player routing headers")
check(Pan115PlaybackRouting.headers(url: URL(string: "https://115.com/master.m3u8")!, common: common)["Cookie"] != nil, "115 HLS authentication")
check(Pan115PlaybackRouting.headers(url: URL(string: "https://115.com.evil.example/movie.mp4")!, common: common)["Cookie"] == nil, "domain boundary")
print("PASS: \(count) production playback routing assertions")
