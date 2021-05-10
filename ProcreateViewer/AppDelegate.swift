import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSUserInterfaceValidations {
    @IBAction func showInfoAction(_ sender: Any) {
        NSApplication.shared.keyWindow?.contentViewController?.performSegue(withIdentifier: "showInfo", sender: self)
    }
    
    @IBAction func showTimelapseAction(_ sender: Any) {
        NSApplication.shared.keyWindow?.contentViewController?.performSegue(withIdentifier: "showTimelapse", sender: self)
    }
    
    func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        // Show timelapse and show info buttons
        if(item.tag == 67 || item.tag == 68) {
            return NSApplication.shared.keyWindow != nil
        }
        
        return true
    }
}

