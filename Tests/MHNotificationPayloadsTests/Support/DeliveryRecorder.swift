import Foundation

actor DeliveryRecorder {
    private var recordedValues = [URL?]()

    func record(_ url: URL?) {
        recordedValues.append(url)
    }

    func values() -> [URL?] {
        recordedValues
    }
}
