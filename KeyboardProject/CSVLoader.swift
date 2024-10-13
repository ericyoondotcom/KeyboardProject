import Foundation

public class CSVLoader {
    public static func loadLatexMacroSymbols(fileName: String) -> Dictionary<String, String>? {
        // Get the path of the CSV file in the main bundle
        var ret: Dictionary<String, String> = Dictionary<String, String>()

        do {
            let contents = try String(contentsOfFile: fileName)
            let lines = contents.components(separatedBy: "\n")
            for line in lines {
                let values = line.components(separatedBy: ",")
                if values.count < 2 {
                    continue
                }
                ret[String(values[0].dropFirst())] = values[1]
            }
        } catch {
            NSLog("Returning nil because error, symbols not loaded")
            return nil
        }
        NSLog("Loaded " + String(ret.keys.count) + " entries of symbols")
        return ret
    }
    
    public static func loadLatexMacroNicknames(fileName: String) -> Dictionary<String, [String]>? {
        // Get the path of the CSV file in the main bundle
        var ret: Dictionary<String, [String]> = Dictionary<String, [String]>()
        
        do {
            let contents = try String(contentsOfFile: fileName)
            let lines = contents.components(separatedBy: "\n")
            // Iterate over the remaining lines
            for line in lines {
                // Split the line into values
                let values = line.components(separatedBy: ",")
                if values.count < 2 {
                    continue
                }
                ret[values[0]] = Array(values[1...])
            }
        } catch {
            NSLog("Returning nil because error, symbols not loaded")
            return nil
        }
        NSLog("Loaded " + String(ret.keys.count) + " entries of nicknames")
        return ret
    }

    public static func loadEmojiFromShortcodes(fileName: String) -> Dictionary<String, [String]>? {
        var ret: Dictionary<String, [String]> = Dictionary<String, [String]>()
        
        do {
            let contents = try String(contentsOfFile: fileName)
            let lines = contents.components(separatedBy: "\n")
            // Iterate over the remaining lines
            for line in lines {
                // Split the line into values
                let values = line.components(separatedBy: ",")
                if values.count < 2 {
                    continue
                }
                ret[values[0]] = Array(values[1...])
            }
        } catch {
            NSLog("Returning nil because error, symbols not loaded")
            return nil
        }
        NSLog("Loaded " + String(ret.keys.count) + " entries of emoji shortcodes")
        return ret
    }
    
    public static func loadEmojiDesc(fileName: String) -> Dictionary<String, String>? {
        var ret: Dictionary<String, String> = Dictionary<String, String>()
        
        do {
            let contents = try String(contentsOfFile: fileName)
            let lines = contents.components(separatedBy: "\n")
            // Iterate over the remaining lines
            for line in lines {
                // Split the line into values
                if let index = line.firstIndex(of: ",") {
                    let firstPart = line[..<index]
                    let secondPart = line[line.index(after: index)...]
                    ret[String(firstPart)] = secondPart.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                }
            }
        } catch {
            NSLog("Returning nil because error, symbols not loaded")
            return nil
        }
        NSLog("Loaded " + String(ret.keys.count) + " entries of emoji descriptions")
        return ret
    }
    
    public static func loadEmojiIndex(filename: URL) -> [String]? {
        do {
            let data = try Data(contentsOf: filename)
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])

            // Assuming your JSON structure is a simple array of strings
            guard let stringArray = jsonObject as? [String] else {
                NSLog("Error: The JSON file does not contain a string array.")
                return nil
            }

            NSLog("Loaded emoji index of length " + String(stringArray.count))
            return stringArray

        } catch {
            NSLog("Error loading or parsing JSON: \(error)")
            return nil
        }
    }
    
    public static func loadEmojiEmbeddings(filename: URL) -> [[Float]]? {
        do {
            let data = try Data(contentsOf: filename)
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
            
            guard let outerArray = jsonObject as? [[Any]] else {
                print("Error: JSON is not a 2D array")
                return nil
            }

            var floatArray: [[Float]] = []
            for innerArray in outerArray {
                var floatInnerArray: [Float] = []
                for number in innerArray {
                    if let decimalNumber = number as? NSDecimalNumber {
                        floatInnerArray.append(decimalNumber.floatValue)
                    } else if let number = number as? NSNumber {
                        floatInnerArray.append(number.floatValue)
                    } else {
                        print("Error: Unexpected data type in array")
                        return nil
                    }
                }
                floatArray.append(floatInnerArray)
            }

            NSLog("Loaded embeddings array of shape " + String(floatArray.count) + "x" + String(floatArray[0].count))
            return floatArray

        } catch {
            NSLog("Error loading or parsing JSON: \(error)")
            return nil
        }
    }
}
