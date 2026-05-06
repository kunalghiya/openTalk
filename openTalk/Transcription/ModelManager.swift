import Foundation

struct WhisperModelOption: Identifiable, Hashable {
    let id: String   // e.g. "openai_whisper-base.en"
    let label: String
    let approxSizeMB: Int
}

enum ModelManager {
    static let recommended: [WhisperModelOption] = [
        .init(id: "openai_whisper-tiny.en",  label: "Tiny (English)",  approxSizeMB: 75),
        .init(id: "openai_whisper-base.en",  label: "Base (English)",  approxSizeMB: 145),
        .init(id: "openai_whisper-small.en", label: "Small (English)", approxSizeMB: 480),
        .init(id: "openai_whisper-tiny",     label: "Tiny (multilingual)",  approxSizeMB: 75),
        .init(id: "openai_whisper-base",     label: "Base (multilingual)",  approxSizeMB: 145),
    ]
}
