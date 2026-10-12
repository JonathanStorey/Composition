// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/NodeProtocol.swift
// dependencies: []

#if canImport(Foundation)
import Foundation

/// A type identified by a UUID, the base that every kind of node refines.
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public protocol NodeProtocol: Identifiable where ID == UUID {}
#endif
