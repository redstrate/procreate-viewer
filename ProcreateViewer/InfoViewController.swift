import Foundation
import Cocoa

class InfoViewController: NSViewController {
    var document: Document?
    
    @IBOutlet weak var timeSpentLabel: NSTextField!
    @IBOutlet weak var layerCountLabel: NSTextField!
    
    override func viewWillAppear() {
        super.viewDidAppear()
        
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .full
        
        let formattedString = formatter.string(from: TimeInterval(document!.info.trackedTime))!
        
        timeSpentLabel.stringValue = "Time Spent: " + formattedString
        
        layerCountLabel.stringValue = "Number of layers: " + String(document!.info.layers.count)
    }
}
