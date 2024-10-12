import Cocoa
import InputMethodKit

@objc(InputController)
class InputController: IMKInputController {
//    func candidates(for target: IMKTextInput) -> [Any]! {
//        return ["Hello", "Bye"]
//    }

    override func inputText(_ string: String!, client sender: Any!) -> Bool {
        guard let client = sender as? IMKTextInput else {
            return false
        }
        
        client.insertText("3" + string, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
        return true
    }
    
//    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
//        let server = self.server()
//        let candidates = IMKCandidates(server: server, panelType: kIMKMain)
//        if let cand = candidates {
//            cand.update()
//        }
//        return true
//    }
}
