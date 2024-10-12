import Cocoa
import InputMethodKit

func removeDupes(arr: [String]) -> [String] {
    return NSOrderedSet(array: arr).map({ $0 as! String })
}

@objc(InputController)
class InputController: IMKInputController {
    private let candidates: IMKCandidates
    private let client: IMKTextInput
    private let controlKeys = [
        kVK_LeftArrow,
        kVK_RightArrow,
        kVK_UpArrow,
        kVK_DownArrow,
        kVK_Escape,
        kVK_ForwardDelete,
        kVK_Delete,
    ]
    private var isSuggesting = false;
    private var isLatexOnly = false;
    private var suggestionInput = "";
    private var lastCharacter: Character? = nil;
    
    private let nonLatexSuggestionsList: Dictionary<String, String> = [
        "happy": "😀",
        "sad": "😢",
        "hot": "🥵",
        "cold": "🥶",
    ]
    private let latexSuggestionsList: Dictionary<String, String> = [
        "phi": "ɸ",
        "forall": "∀",
        "lambda": "λ",
        "dental fricative": "θ",
        "alveolar plosive": "t",
        "alveolar approximant": "ɹ"
    ]

    override init!(server: IMKServer, delegate: Any, client inputClient: Any) {
        let candidatesWrapped = IMKCandidates(server: server, panelType: kIMKSingleColumnScrollingCandidatePanel)
        guard let clientUnwrapped = inputClient as? IMKTextInput else {
            return nil
        }
        guard let candidatesUnwrapped = candidatesWrapped else {
            return nil
        }
        self.candidates = candidatesUnwrapped
        self.client = clientUnwrapped
        
        super.init(server: server, delegate: delegate, client: inputClient)
    }

    override func candidates(_ sender: Any) -> [Any] {
        if suggestionInput.isEmpty {
            if isLatexOnly {
                return removeDupes(arr: Array(latexSuggestionsList.values))
            }
            return removeDupes(arr: Array(nonLatexSuggestionsList.values) + Array(latexSuggestionsList.values))
        }
        var filtered = Array(latexSuggestionsList.filter { $0.key.hasPrefix(suggestionInput) }.values)
        if !isLatexOnly {
            let nonLatexFiltered = Array(nonLatexSuggestionsList.filter { $0.key.hasPrefix(suggestionInput) }.values)
            filtered = nonLatexFiltered + filtered
            filtered.append(":" + suggestionInput)
        } else {
            filtered.append("\\" + suggestionInput)
        }
        return removeDupes(arr: filtered)
    }

    override func candidateSelected(_ candidateString: NSAttributedString) {
        insertText(text: candidateString.string)
        candidates.hide()
        stopSuggesting()
        lastCharacter = Character(" ")
    }

    override func candidateSelectionChanged(_ candidateString: NSAttributedString) {
        NSLog("%@", "\(#function)")
    }

    private func startSuggestionInput(isLatexOnly: Bool) {
        isSuggesting = true;
        self.isLatexOnly = isLatexOnly;
        suggestionInput = "";
    }

    private func stopSuggesting() {
        isSuggesting = false;
        isLatexOnly = false;
        suggestionInput = "";
    }

    override func handle(_ event: NSEvent, client sender: Any) -> Bool {
        if event.characters == ":" && !isLatexOnly {
            if isSuggesting && candidates.isVisible() {
                let nonLatexResult = nonLatexSuggestionsList[suggestionInput]
                let latexResult = latexSuggestionsList[suggestionInput]

                if let nonLatexResult = nonLatexResult {
                    insertText(text: nonLatexResult)
                    stopSuggesting()
                    candidates.hide()
                    lastCharacter = Character(" ")
                    return true
                }
                if let latexResult = latexResult {
                    insertText(text: latexResult)
                    stopSuggesting()
                    candidates.hide()
                    lastCharacter = Character(" ")
                    return true
                }
                insertText(text: ":" + suggestionInput + ":")
                stopSuggesting()
                candidates.hide()
                return true
            }
            if let lastCharacter = lastCharacter {
                if lastCharacter.isWhitespace {
                    startSuggestionInput(isLatexOnly: false)
                    candidates.update()
                    candidates.show()
                    return true
                }
            } else {
                startSuggestionInput(isLatexOnly: false)
                candidates.update()
                candidates.show()
                return true
            }
            return false
        }
        if event.characters == "\\" {
            startSuggestionInput(isLatexOnly: true)
            candidates.update()
            candidates.show()
            return true
        }
        if event.keyCode == kVK_Delete && candidates.isVisible() && isSuggesting {
            if suggestionInput.count == 0 {
                suggestionInput = "";
                isSuggesting = false;
                isLatexOnly = false;
                candidates.hide()
                return true
            }
            suggestionInput = String(suggestionInput.prefix(suggestionInput.count - 1))
            candidates.update()
            return true
        }
        if event.keyCode == kVK_Escape {
            onSuggestionDismiss()
            return false
        }
        if event.keyCode == kVK_Return {
            if candidates.isVisible() {
                candidates.interpretKeyEvents([ event ])
                return true
            }
            return false
        }

        // The return value is whether the system interprets the keystroke with default behavior
        // If the event had no associated character, i.e. arrow keys, let the system do its thing
        // If the event was a character that should be typed, consume it
        if controlKeys.contains(Int(event.keyCode)) {
            if candidates.isVisible() {
                candidates.interpretKeyEvents([ event ])
            }
            return false
        }

        if let chars = event.characters {
            if chars.count != 0 {
                lastCharacter = chars.last!
            }
            if isSuggesting {
                suggestionInput += chars
            } else {
                insertText(text: chars)
            }
        }

        candidates.update()
        return true
    }

    func onSuggestionDismiss() {
        if isLatexOnly {
            insertText(text: "\\" + suggestionInput)
        } else {
            insertText(text: ":" + suggestionInput)
        }
        stopSuggesting()
        candidates.hide()
    }

    func insertText(text: String) {
        client.insertText(text, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
    }
}
