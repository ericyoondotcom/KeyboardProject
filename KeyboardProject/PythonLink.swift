//
//  PythonLink.swift
//  KeyboardProject
//
//  Created by Eric Yoon on 10/12/24.
//

import Foundation


class PythonLink {
    private var scriptPath = "/Users/yooniverse/Documents/Git/KeyboardProject/backend/test_python_link.py"
    private var process: Process
    private var inputPipe: Pipe
    private var outputPipe: Pipe

    init?(pythonExecutablePath: String = "/usr/bin/python3") {
        // 1. Set up the process
        self.process = Process()
        self.process.executableURL = URL(fileURLWithPath: pythonExecutablePath)
        self.process.arguments = [scriptPath]

        // 2. Create pipes for communication
        self.inputPipe = Pipe()
        self.outputPipe = Pipe()
        self.process.standardInput = inputPipe
        self.process.standardOutput = outputPipe

        // 3. Launch the process
        do {
            try self.process.run()
        } catch {
            print("Error running Python process: \(error)")
            return nil
        }
    }

    func sendStringAndWaitForResult(inputString: String) async -> [String]? {
        // 4. Send the input string to Python
        var inputData = inputString.data(using: .utf8)!
        if inputString.isEmpty {
            inputData = "<EMPTY>".data(using: .utf8)!
        }
        self.inputPipe.fileHandleForWriting.write(inputData)
        self.inputPipe.fileHandleForWriting.closeFile()

        // 5. Read the output from Python asynchronously
        return await withCheckedContinuation { continuation in
            self.outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                guard let self = self else { return } // Ensure self is still valid

                // Remove the readabilityHandler to prevent multiple calls
                self.outputPipe.fileHandleForReading.readabilityHandler = nil

                let outputData = handle.readDataToEndOfFile()
                guard let outputString = String(data: outputData, encoding: .utf8) else {
                    continuation.resume(returning: nil)
                    return
                }

                let outputArray = outputString.split(separator: ",").map { String($0) }
                continuation.resume(returning: outputArray)
            }
        }
    }

    deinit {
        // Terminate the process when the PythonLink instance is deallocated
        self.process.terminate()
    }
}
