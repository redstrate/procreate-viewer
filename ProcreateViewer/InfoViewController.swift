import Foundation
import Cocoa

class InfoViewController: NSViewController {
    var document: Document?
    
    @IBOutlet weak var timeSpentLabel: NSTextField!

    override func viewDidAppear() {
        super.viewDidAppear()
        
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .full
        
        let formattedString = formatter.string(from: TimeInterval(document!.info.tracked_time))!
        
        timeSpentLabel.stringValue = "Time Spent: " + formattedString
    }
}
