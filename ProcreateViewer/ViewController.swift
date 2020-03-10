import Foundation
import Cocoa

class ViewController: NSViewController {
    @IBOutlet weak var imageView: NSImageView!
    
    override func viewWillAppear() {
        let document = self.view.window?.windowController?.document as? Document
        
        imageView.image = document?.image
    }
}
