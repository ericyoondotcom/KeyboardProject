import Cocoa
import InputMethodKit

func removeDupes(arr: [String]) -> [String] {
    return NSOrderedSet(array: arr).map({ $0 as! String })
}

func removeDupes(arr: Dictionary<String, String>.Values) -> [String] {
    return removeDupes(arr: Array(arr))
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
    private var isLatexOnly = false; // if the user invoked the popup with a backslash
    private var suggestionInput = "";
    private var lastCharacter: Character? = nil;
    
    private var suggestionsLatexCanonical: Dictionary<String, String> = [:]
    private var suggestionsLatexSemantic: Dictionary<String, String> = [:]
    private var suggestionsEmojiCanonical: Dictionary<String, String> = [:]
    private var suggestionsEmojiSemantic: Dictionary<String, String> = [:]
    
    
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
        
        
        loadSuggestionArrays()
    }
    
    func loadSuggestionArrays() {
        let macroSymbols = CSVLoader.loadLatexMacroSymbols(fileName: Bundle.main.url(forResource: "latex_unicode", withExtension: "csv")!.path)
        let macroNicknames = CSVLoader.loadLatexMacroNicknames(fileName: Bundle.main.url(forResource: "latex_data", withExtension: "csv")!.path)
        guard let macroSymbols = macroSymbols else {
            return
        }
        for key in macroSymbols.keys {
            guard let symb = macroSymbols[key] else {
                continue
            }
            let replaced = symb.replacingOccurrences(of: "\\", with: "", options: .literal, range: nil)
            suggestionsLatexCanonical[key] = replaced
        }
        guard let macroNicknames = macroNicknames else {
            return
        }
        for key in macroNicknames.keys {
            let symbol = macroSymbols[String(key.dropFirst())]
            guard let nicknamesList = macroNicknames[key] else {
                continue
            }
            for nick_name in nicknamesList {
                suggestionsLatexSemantic[nick_name.lowercased()] = symbol
            }
                    
        }
        
        
        let emojiShortcodes = CSVLoader.loadEmojiFromShortcodes(fileName: Bundle.main.url(forResource: "emoji_transformed_stage_2", withExtension: "csv")!.path)
        guard let emojiShortcdes = emojiShortcdoes else {
            return
        }
        for key in emojiShortcdes.keys {
            guard let shortcodesList = emojiShortcdes[key] else {
                continue
            }
            for shortcode in shortcodesList {
                suggestionsEmojiCanonical[shortcode] = key
            }
        }
    }

    override func candidates(_ sender: Any) -> [Any] {
        if suggestionInput.isEmpty {
            // Present EVERY suggestion to the user
            if isLatexOnly {
                return ["\\"] + removeDupes(arr: Array(suggestionsLatexCanonical.values.prefix(10)))
            }
            return [":"] + removeDupes(arr: Array(suggestionsEmojiCanonical.values.prefix(10)))
        }
        
        var suggestions: [String] = []
        suggestions.append(
            (isLatexOnly ? "\\" : ":") +
            suggestionInput
        )
        if !isLatexOnly {
            // If the user wants emojis, show them emojis
            let filteredEmojiCanonical = filterWithLimit(dict: suggestionsEmojiCanonical, suggestionInput: suggestionInput)
            let filteredEmojiSemantic = filterWithLimit(dict: suggestionsEmojiSemantic, suggestionInput: suggestionInput)
        
            suggestions = suggestions + filteredEmojiCanonical + filteredEmojiSemantic
        }
        
        let filteredLatexCanonical = filterWithLimit(dict: suggestionsLatexCanonical, suggestionInput: suggestionInput)
        let filteredLatexSemantic = filterWithLimit(dict: suggestionsLatexSemantic, suggestionInput: suggestionInput.lowercased())
    
        suggestions = suggestions + filteredLatexCanonical + filteredLatexSemantic

        // Finally, we need to add the default suggestion if
        // the user just wants to type the plaintext and not
        // invoke a macro.
        
        return removeDupes(arr: suggestions)
    }
    
    private func filterWithLimit(dict: Dictionary<String, String>, suggestionInput: String) -> [String] {
        var ret: [String] = []
        var count = 0
        for key in dict.keys {
            if key.hasPrefix(suggestionInput) {
                count += 1
                if let val = dict[key] {
                    ret.append(val)
                }
            }
//            if count > 10 {
//                break
//            }
        }
        return ret
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
                let semanticResult = suggestionsEmojiSemantic[suggestionInput]
                let canonicalResult = suggestionsEmojiCanonical[suggestionInput]

                
                if let canonicalResult = canonicalResult {
                    insertText(text: canonicalResult)
                    stopSuggesting()
                    candidates.hide()
                    lastCharacter = Character(" ")
                    return true
                }
                if let semanticResult = semanticResult {
                    insertText(text: semanticResult)
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
