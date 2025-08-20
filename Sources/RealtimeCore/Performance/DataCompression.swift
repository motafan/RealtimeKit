// DataCompression.swift
// Data compression utilities for network optimization

import Foundation
import Compression

/// Data compression manager for optimizing network transfers
public final class DataCompressionManager: @unchecked Sendable {
    public static let shared = DataCompressionManager()
    
    private let compressionThreshold: Int = 1024 // Only compress data larger than 1KB
    private let compressionAlgorithm: compression_algorithm = COMPRESSION_LZFSE
    
    private init() {}
    
    /// Compress data if it meets the threshold
    /// - Parameter data: Data to compress
    /// - Returns: Compressed data with metadata
    public func compressIfBeneficial(_ data: Data) -> CompressedData {
        guard data.count >= compressionThreshold else {
            return CompressedData(data: data, isCompressed: false, originalSize: data.count)
        }
        
        do {
            let compressedData = try compress(data)
            
            // Only use compression if it actually reduces size significantly
            if compressedData.count < Int(Double(data.count) * 0.9) { // At least 10% reduction
                return CompressedData(
                    data: compressedData,
                    isCompressed: true,
                    originalSize: data.count
                )
            } else {
                return CompressedData(
                    data: data,
                    isCompressed: false,
                    originalSize: data.count
                )
            }
        } catch {
            // If compression fails, return original data
            return CompressedData(data: data, isCompressed: false, originalSize: data.count)
        }
    }
    
    /// Compress data using the configured algorithm
    /// - Parameter data: Data to compress
    /// - Returns: Compressed data
    public func compress(_ data: Data) throws -> Data {
        return try data.withUnsafeBytes { bytes in
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count)
            defer { buffer.deallocate() }
            
            let compressedSize = compression_encode_buffer(
                buffer, data.count,
                bytes.bindMemory(to: UInt8.self).baseAddress!, data.count,
                nil, compressionAlgorithm
            )
            
            guard compressedSize > 0 else {
                throw CompressionError.compressionFailed
            }
            
            return Data(bytes: buffer, count: compressedSize)
        }
    }
    
    /// Decompress data
    /// - Parameters:
    ///   - compressedData: Compressed data
    ///   - originalSize: Original size of the data
    /// - Returns: Decompressed data
    public func decompress(_ compressedData: Data, originalSize: Int) throws -> Data {
        return try compressedData.withUnsafeBytes { bytes in
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: originalSize)
            defer { buffer.deallocate() }
            
            let decompressedSize = compression_decode_buffer(
                buffer, originalSize,
                bytes.bindMemory(to: UInt8.self).baseAddress!, compressedData.count,
                nil, compressionAlgorithm
            )
            
            guard decompressedSize == originalSize else {
                throw CompressionError.decompressionFailed
            }
            
            return Data(bytes: buffer, count: decompressedSize)
        }
    }
    
    /// Get compression statistics
    /// - Returns: Compression statistics
    public func getStatistics() -> CompressionStatistics {
        // In a real implementation, you would track these statistics
        return CompressionStatistics(
            totalBytesProcessed: 0,
            totalBytesCompressed: 0,
            compressionRatio: 0.0,
            compressionAttempts: 0,
            successfulCompressions: 0
        )
    }
}

/// Compressed data container
public struct CompressedData {
    public let data: Data
    public let isCompressed: Bool
    public let originalSize: Int
    
    /// Compression ratio (0.0 to 1.0, lower is better)
    public var compressionRatio: Double {
        guard isCompressed && originalSize > 0 else { return 1.0 }
        return Double(data.count) / Double(originalSize)
    }
    
    /// Bytes saved through compression
    public var bytesSaved: Int {
        guard isCompressed else { return 0 }
        return originalSize - data.count
    }
    
    /// Decompress the data if it's compressed
    /// - Returns: Original data
    public func decompress() throws -> Data {
        guard isCompressed else { return data }
        return try DataCompressionManager.shared.decompress(data, originalSize: originalSize)
    }
}

/// Compression statistics
public struct CompressionStatistics {
    public let totalBytesProcessed: Int
    public let totalBytesCompressed: Int
    public let compressionRatio: Double
    public let compressionAttempts: Int
    public let successfulCompressions: Int
    
    public var successRate: Double {
        guard compressionAttempts > 0 else { return 0.0 }
        return Double(successfulCompressions) / Double(compressionAttempts)
    }
    
    public var averageCompressionRatio: Double {
        guard totalBytesProcessed > 0 else { return 1.0 }
        return Double(totalBytesCompressed) / Double(totalBytesProcessed)
    }
}

/// Compression errors
public enum CompressionError: Error, LocalizedError {
    case compressionFailed
    case decompressionFailed
    case invalidData
    
    public var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Failed to compress data"
        case .decompressionFailed:
            return "Failed to decompress data"
        case .invalidData:
            return "Invalid data for compression/decompression"
        }
    }
}

// MARK: - Message Compression Extensions

extension RealtimeMessage {
    /// Create a compressed version of the message
    /// - Returns: Compressed message data
    public func compressed() throws -> CompressedData {
        let encoder = JSONEncoder()
        let messageData = try encoder.encode(self)
        return DataCompressionManager.shared.compressIfBeneficial(messageData)
    }
    
    /// Create message from compressed data
    /// - Parameter compressedData: Compressed message data
    /// - Returns: Decoded message
    public static func fromCompressed(_ compressedData: CompressedData) throws -> RealtimeMessage {
        let decompressedData = try compressedData.decompress()
        let decoder = JSONDecoder()
        return try decoder.decode(RealtimeMessage.self, from: decompressedData)
    }
}

extension Array where Element == UserVolumeInfo {
    /// Create compressed version of volume info array
    /// - Returns: Compressed volume data
    public func compressed() throws -> CompressedData {
        let encoder = JSONEncoder()
        let volumeData = try encoder.encode(self)
        return DataCompressionManager.shared.compressIfBeneficial(volumeData)
    }
    
    /// Create volume info array from compressed data
    /// - Parameter compressedData: Compressed volume data
    /// - Returns: Decoded volume info array
    public static func fromCompressed(_ compressedData: CompressedData) throws -> [UserVolumeInfo] {
        let decompressedData = try compressedData.decompress()
        let decoder = JSONDecoder()
        return try decoder.decode([UserVolumeInfo].self, from: decompressedData)
    }
}