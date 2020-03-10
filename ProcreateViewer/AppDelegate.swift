import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSUserInterfaceValidations {
    @IBAction func showInfoAction(_ sender: Any) {
        NSApplication.shared.keyWindow?.contentViewController?.performSegue(withIdentifier: "showInfo", sender: self)
    }
    
    func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        if(item.tag == 67) {
            return NSApplication.shared.keyWindow
                
                != nil
        }
        
        return true
    }
}

