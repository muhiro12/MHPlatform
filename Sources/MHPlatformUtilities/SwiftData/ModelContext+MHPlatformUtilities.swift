import SwiftData

public extension ModelContext {
    /// Fetches the first model matching the given descriptor.
    /// - Parameter descriptor: A fetch descriptor describing the query.
    /// - Returns: The first matching model, or `nil` when no results exist.
    /// - Throws: Any error thrown by the underlying fetch operation.
    func fetchFirst<Model>(
        _ descriptor: FetchDescriptor<Model>
    ) throws -> Model? where Model: PersistentModel {
        var descriptor = descriptor
        descriptor.fetchLimit = 1
        return try fetch(descriptor).first
    }

    /// Fetches a single random model from the result set described by the descriptor.
    /// - Parameter descriptor: A fetch descriptor describing the population.
    /// - Returns: A random model from the population, or `nil` when the population is empty.
    /// - Throws: Any error thrown by `fetchCount` or the subsequent fetch.
    func fetchRandom<Model>(
        _ descriptor: FetchDescriptor<Model>
    ) throws -> Model? where Model: PersistentModel {
        var generator = SystemRandomNumberGenerator()
        return try fetchRandom(descriptor, using: &generator)
    }

    /// Fetches a single random model using the supplied random number generator.
    /// - Parameters:
    ///   - descriptor: A fetch descriptor describing the population.
    ///   - generator: The random number generator used to choose the fetch offset.
    /// - Returns: A random model from the population, or `nil` when the population is empty.
    /// - Throws: Any error thrown by `fetchCount` or the subsequent fetch.
    func fetchRandom<Model, Generator>(
        _ descriptor: FetchDescriptor<Model>,
        using generator: inout Generator
    ) throws -> Model? where Model: PersistentModel, Generator: RandomNumberGenerator {
        let count = try fetchCount(descriptor)

        guard count > .zero else {
            return nil
        }

        let offset = Int.random(in: .zero..<count, using: &generator)

        var descriptor = descriptor
        descriptor.fetchOffset = offset

        return try fetchFirst(descriptor)
    }
}
