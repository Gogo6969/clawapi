import Foundation

// MARK: - JSON-RPC 2.0 Types

/// A JSON-RPC 2.0 request ID — can be an integer or a string.
public enum JSONRPCId: Sendable, Equatable {
    case int(Int)
    case string(String)
}

extension JSONRPCId: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            self = .int(intVal)
        } else if let strVal = try? container.decode(String.self) {
            self = .string(strVal)
        } else {
            throw DecodingError.typeMismatch(JSONRPCId.self, .init(codingPath: decoder.codingPath, debugDescription: "Expected Int or String for JSON-RPC id"))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .int(let v): try container.encode(v)
        case .string(let v): try container.encode(v)
        }
    }
}

/// A JSON-RPC 2.0 request or notification.
public struct JSONRPCRequest: Codable, Sendable {
    public let jsonrpc: String
    public let id: JSONRPCId?
    public let method: String
    public let params: JSONValue?

    public init(jsonrpc: String = "2.0", id: JSONRPCId? = nil, method: String, params: JSONValue? = nil) {
        self.jsonrpc = jsonrpc
        self.id = id
        self.method = method
        self.params = params
    }
}

/// A JSON-RPC 2.0 response.
public struct JSONRPCResponse: Codable, Sendable {
    public let jsonrpc: String
    public let id: JSONRPCId?
    public let result: JSONValue?
    public let error: JSONRPCError?

    public init(id: JSONRPCId?, result: JSONValue) {
        self.jsonrpc = "2.0"
        self.id = id
        self.result = result
        self.error = nil
    }

    public init(id: JSONRPCId?, error: JSONRPCError) {
        self.jsonrpc = "2.0"
        self.id = id
        self.result = nil
        self.error = error
    }
}

/// A JSON-RPC 2.0 error object.
public struct JSONRPCError: Codable, Sendable {
    public let code: Int
    public let message: String
    public let data: JSONValue?

    public init(code: Int, message: String, data: JSONValue? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }

    // Standard JSON-RPC error codes
    public static func parseError(_ detail: String? = nil) -> JSONRPCError {
        JSONRPCError(code: -32700, message: "Parse error", data: detail.map { .string($0) })
    }
    public static func methodNotFound(_ method: String) -> JSONRPCError {
        JSONRPCError(code: -32601, message: "Method not found: \(method)")
    }
    public static func invalidParams(_ detail: String) -> JSONRPCError {
        JSONRPCError(code: -32602, message: "Invalid params: \(detail)")
    }
    public static func internalError(_ detail: String) -> JSONRPCError {
        JSONRPCError(code: -32603, message: "Internal error: \(detail)")
    }
}

// MARK: - JSONValue (Arbitrary JSON)

/// A recursive enum representing any JSON value.
/// Used for MCP params/results which have varying shapes.
public enum JSONValue: Sendable, Equatable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])
}

extension JSONValue: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let v = try? container.decode(Bool.self) {
            self = .bool(v)
        } else if let v = try? container.decode(Int.self) {
            self = .int(v)
        } else if let v = try? container.decode(Double.self) {
            self = .double(v)
        } else if let v = try? container.decode(String.self) {
            self = .string(v)
        } else if let v = try? container.decode([JSONValue].self) {
            self = .array(v)
        } else if let v = try? container.decode([String: JSONValue].self) {
            self = .object(v)
        } else {
            throw DecodingError.typeMismatch(JSONValue.self, .init(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON value"))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let v): try container.encode(v)
        case .int(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .string(let v): try container.encode(v)
        case .array(let v): try container.encode(v)
        case .object(let v): try container.encode(v)
        }
    }
}

// MARK: - JSONValue Convenience

extension JSONValue {
    public var stringValue: String? {
        if case .string(let v) = self { return v }
        return nil
    }

    public var intValue: Int? {
        if case .int(let v) = self { return v }
        return nil
    }

    public var boolValue: Bool? {
        if case .bool(let v) = self { return v }
        return nil
    }

    public var objectValue: [String: JSONValue]? {
        if case .object(let v) = self { return v }
        return nil
    }

    public var arrayValue: [JSONValue]? {
        if case .array(let v) = self { return v }
        return nil
    }

    public subscript(key: String) -> JSONValue? {
        if case .object(let dict) = self { return dict[key] }
        return nil
    }

    /// Build an MCP text content block.
    public static func textContent(_ text: String) -> JSONValue {
        .object(["type": .string("text"), "text": .string(text)])
    }

    /// Build an MCP tool result (content array + isError flag).
    public static func toolResult(text: String, isError: Bool = false) -> JSONValue {
        .object([
            "content": .array([textContent(text)]),
            "isError": .bool(isError)
        ])
    }
}
