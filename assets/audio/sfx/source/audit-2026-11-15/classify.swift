import Foundation
import SoundAnalysis
import CoreMedia
final class Observer: NSObject, SNResultsObserving {
 var rows: [[String:Any]] = []
 func request(_ request: SNRequest, didProduce result: SNResult) {
  guard let r = result as? SNClassificationResult else { return }
  rows.append(["time":CMTimeGetSeconds(r.timeRange.start),"labels":r.classifications.prefix(8).map{["id":$0.identifier,"confidence":$0.confidence] as [String:Any]}])
 }
 func request(_ request: SNRequest, didFailWithError error: Error) { print("ERROR \(error)") }
 func requestDidComplete(_ request: SNRequest) {}
}
for path in CommandLine.arguments.dropFirst() {
 do {
  let observer = Observer()
  let analyzer = try SNAudioFileAnalyzer(url: URL(fileURLWithPath:path))
  let request = try SNClassifySoundRequest(classifierIdentifier: .version1)
  request.windowDuration = CMTime(seconds:0.5, preferredTimescale:48000)
  request.overlapFactor = 0
  try analyzer.add(request, withObserver:observer)
  analyzer.analyze()
  let output:[String:Any] = ["file":URL(fileURLWithPath:path).lastPathComponent,"results":observer.rows]
  print(String(data:try JSONSerialization.data(withJSONObject:output,options:[.sortedKeys]),encoding:.utf8)!)
 } catch { print("ERROR \(path) \(error)") }
}
