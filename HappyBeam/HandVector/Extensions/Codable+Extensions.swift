//
//  Codable+Extensions.swift
//  HappyBeam
//
//  Ported from HandVector
//

import Foundation


extension Encodable {
    func toJson(encoding: String.Encoding = .utf8) -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: encoding)
    }
}
extension String {
    func toModel<T>(_ type: T.Type, using encoding: String.Encoding = .utf8) -> T? where T : Decodable {
        guard let data = self.data(using: encoding) else { return nil }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print(error)
        }
        return nil
    }
}
