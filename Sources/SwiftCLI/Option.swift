//
//  Option.swift
//  SwiftCLI
//
//  Created by Jake Heiser on 3/28/17.
//  Copyright © 2017 jakeheis. All rights reserved.
//

public protocol Option: class, CustomStringConvertible {
    var names: [String] { get }
    var shortDescription: String { get }
    var identifier: String { get }
    var isVariadic: Bool { get }
    var completion: Completion? { get }
}

public extension Option {
    
    var description: String {
        return "\(type(of: self))(\(identifier))"
    }
    
    func usage(padding: Int) -> String {
        let spacing = String(repeating: " ", count: padding - identifier.count)
        let descriptionNewlineSpacing = String(repeating: " ", count: padding)
        let description = shortDescription.replacingOccurrences(of: "\n", with: "\n\(descriptionNewlineSpacing)")
        return "\(identifier)\(spacing)\(description)"
    }
    
}

public class Flag: Option {
    
    public let names: [String]
    public let shortDescription: String
    public private(set) var value: Bool
    public let isVariadic = false
    public let completion: Completion? = nil
    
    public var identifier: String {
        return names.joined(separator: ", ")
    }
    
    /// Creates a new flag
    ///
    /// - Parameters:
    ///   - names: the names for the flag; convention is to include a short name (-a) and a long name (--all)
    ///   - description: A short description of what this flag does for usage statements
    ///   - defaultValue: the default value of this flag; default false
    public init(_ names: String ..., description: String = "", defaultValue: Bool = false) {
        self.names = names
        self.value = defaultValue
        self.shortDescription = description
    }
    
    /// Toggles the flag's value; don't call directly
    public func toggle() {
        value = !value
    }
    
}

public enum UpdateError: Error {
    case conversionError
    case validationError(String)
}

public protocol AnyKey: Option {
    var valueType: Any.Type { get }
    
    func updateValue(_ value: String) throws
}

public struct Validation<T> {
    
    public typealias ValidatorBlock = (T) -> Bool
    
    public static func custom(_ validator: @escaping ValidatorBlock, _ message: String) -> Validation {
        return .init(validator, message)
    }
    
    public let block: ValidatorBlock
    public let message: String
    
    init(_ block: @escaping ValidatorBlock, _ message: String) {
        self.block = block
        self.message = message
    }
    
    public func validate(_ value: T) throws {
        guard block(value) else {
            throw UpdateError.validationError(message)
        }
    }
    
}

public extension Validation where T: Comparable {
    
    public static func greaterThan(_ value: T) -> Validation {
        return .init({ $0 > value }, "Must be greater than \(value)")
    }
    
}

public class Key<T: ConvertibleFromString>: AnyKey {
    
//    public typealias Validation = (T) -> Bool
    
    public let names: [String]
    public let shortDescription: String
    public private(set) var value: T?
    public let isVariadic = false
    public let completion: Completion?
    public let validations: [Validation<T>]
    
    public var valueType: Any.Type {
        return T.self
    }
    
    public var identifier: String {
        return names.joined(separator: ", ") + " <value>"
    }
    
    /// Creates a new key
    ///
    /// - Parameters:
    ///   - names: the names for the key; convention is to include a short name (-m) and a long name (--message)
    ///   - description: A short description of what this key does for usage statements
    public init(_ names: String ..., description: String = "", completion: Completion = .filename, validations: [Validation<T>] = []) {
        self.names = names
        self.shortDescription = description
        self.completion = completion
        self.validations = validations
    }
    
    /// Toggles the key's value; don't call directly
    public func updateValue(_ value: String) throws {
        guard let value = T.convert(from: value) else {
            throw UpdateError.conversionError
        }
        for validation in validations {
            try validation.validate(value)
        }
        self.value = value
    }
    
}

public class VariadicKey<T: ConvertibleFromString>: AnyKey {
    
    public let names: [String]
    public let shortDescription: String
    public private(set) var values: [T] = []
    public let isVariadic = true
    public let completion: Completion?
    public let validations: [Validation<T>]
    
    public var valueType: Any.Type {
        return T.self
    }
    
    public var identifier: String {
        return names.joined(separator: ", ") + " <value>"
    }
    
    /// Creates a new variadic key
    ///
    /// - Parameters:
    ///   - names: the names for the key; convention is to include a short name (-m) and a long name (--message)
    ///   - description: A short description of what this key does for usage statements
    public init(_ names: String ..., description: String = "", completion: Completion = .filename, validations: [Validation<T>] = []) {
        self.names = names
        self.shortDescription = description
        self.completion = completion
        self.validations = validations
    }
    
    /// Toggles the key's value; don't call directly
    public func updateValue(_ value: String) throws {
        guard let value = T.convert(from: value) else {
            throw UpdateError.conversionError
        }
        for validation in validations {
            try validation.validate(value)
        }
        values.append(value)
    }
    
}

// MARK: - ConvertibleFromString

/// A type that can be created from a string
public protocol ConvertibleFromString {
  /// Returns an instance of the conforming type from a string representation
  static func convert(from: String) -> Self?
}

extension ConvertibleFromString where Self: LosslessStringConvertible {
  public static func convert(from: String) -> Self? {
    return Self(from)
  }
}

extension ConvertibleFromString where Self: RawRepresentable, Self.RawValue: ConvertibleFromString {
  public static func convert(from: String) -> Self? {
    guard let val = RawValue.convert(from: from) else {
      return nil
    }
    return Self.init(rawValue: val)
  }
}

extension String: ConvertibleFromString {}
extension Int: ConvertibleFromString {}
extension Float: ConvertibleFromString {}
extension Double: ConvertibleFromString {}

extension Bool: ConvertibleFromString {
  /// Returns a bool from a string representation
  ///
  /// - parameter from: A string representation of a bool value
  ///
  /// This is case insensitive and recognizes several representations:
  ///
  /// - true/false
  /// - t/f
  /// - yes/no
  /// - y/n
  public static func convert(from: String) -> Bool? {
        let lowercased = from.lowercased()
        
        if ["y", "yes", "t", "true"].contains(lowercased) { return true }
        if ["n", "no", "f", "false"].contains(lowercased) { return false }
        
        return nil
    }
}
