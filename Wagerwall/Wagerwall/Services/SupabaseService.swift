import Foundation
import Supabase

let supabase: SupabaseClient = {
    let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)

            // Try full ISO8601 with fractional seconds first (Supabase default)
            let iso8601Fractional = ISO8601DateFormatter()
            iso8601Fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso8601Fractional.date(from: string) { return date }

            // Fall back to ISO8601 without fractional seconds
            let iso8601 = ISO8601DateFormatter()
            iso8601.formatOptions = [.withInternetDateTime]
            if let date = iso8601.date(from: string) { return date }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(string)"
            )
        }
        return decoder
    }()

    return SupabaseClient(
        supabaseURL: URL(string: Config.supabaseURL)!,
        supabaseKey: Config.supabaseAnonKey,
        options: SupabaseClientOptions(
            db: .init(encoder: encoder, decoder: decoder)
        )
    )
}()
