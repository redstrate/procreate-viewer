import Foundation
import Cocoa
import AVKit
import AVFoundation
import ZIPFoundation

class TimelapseViewController: NSViewController {
    var document: Document?
            
    @IBOutlet weak var playerView: AVPlayerView!
    
    override func viewWillAppear() {
        super.viewDidAppear()
        
        guard let archive = Archive(data: (document?.data)!, accessMode: Archive.AccessMode.read) else  {
            return
        }
        
        let directory = NSTemporaryDirectory()
        
        var entries: [AVPlayerItem] = []
        for entry in archive.makeIterator() {
            if entry.path.contains(VideoPath) {
                let fileName = NSUUID().uuidString + ".mp4"
                
                // This returns a URL? even though it is an NSURL class method
                let fullURL = NSURL.fileURL(withPathComponents: [directory, fileName])!
                
                try? archive.extract(entry, to: fullURL)
                
                entries.append(AVPlayerItem(url: fullURL))
            }
        }
        
        playerView?.player = AVQueuePlayer(items: entries)
    }
}
