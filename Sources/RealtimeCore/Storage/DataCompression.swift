import Foundation
import Compression

/// Data compression utilities for optimizing network transmission
/// 需求: 14.2 - 实现连接池和数据压缩优化
public class DataCompression {
    
    // MARK: - Compression Algorithms
    
    public enum CompressionAlgorithm {
        case lz4
        case lzfse
        case zlib
        case lzma
        
        var algorithm: compression_algorithm {
            switch self {
            case .lz4: return COMPRESSION_LZ4
            case .lzfse: return COMPRESSION_LZFSE
            case .zlib: return COMPRESSION_ZLIB
            case .lzma: return COMPRESSION_LZMA
            }
        }
        
        var displayName: String {
            switch self {
            case .lz4: return "LZ4"
            case .lzfse: return "LZFSE"
            case .zlib: return "ZLIB"
            case .lzma: return "LZMA"
            }
        }
    }
    
    // MARK: - Compression Result
    
    public struct CompressionResult {
        public let originalSize: Int
        public let compressedSize: Int
        public let compressionRatio: Double
        public let algorithm: CompressionAlgorithm
        public let compressionTime: TimeInterval
        public let data: Data
        
        public var spaceSaved: Int {
            return originalSize - compressedSize
        }
        
        public var spaceSavedPercentage: Double {
            return originalSize > 0 ? Double(spaceSaved) / Double(originalSize) * 100 : 0
        }
        
        public var description: String {
            return """
            Compression Result (\(algorithm.displayName)):
            - Original Size: \(originalSize) bytes
            - Compressed Size: \(compressedSize) bytes
            - Compression Ratio: \(String(format: "%.2f", compressionRatio))
            - Space Saved: \(String(format: "%.1f%%", spaceSavedPercentage))
            - Compression Time: \(String(format: "%.4f", compressionTime))s
            """
        }
    }
    
    // MARK: - Decompression Result
    
    public struct DecompressionResult {
        public let compressedSize: Int
        public let decompressedSize: Int
        public let algorithm: CompressionAlgorithm
        public let decompressionTime: TimeInterval
        public let data: Data
        
        public var description: String {
            return """
            Decompression Result (\(algorithm.displayName)):
            - Compressed Size: \(compressedSize) bytes
            - Decompressed Size: \(decompressedSize) bytes
            - Decompression Time: \(String(format: "%.4f", decompressionTime))s
            """
        }
    }
    
    // MARK: - Compression Methods
    
    /// Compress data using specified algorithm
    /// - Parameters:
    ///   - data: Data to compress
    ///   - algorithm: Compression algorithm to use
    /// - Returns: Compression result
    /// - Throws: Compression error
    public static func compress(
        data: Data,
        using algorithm: CompressionAlgorithm = .lz4
    ) throws -> CompressionResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let compressedData = try data.withUnsafeBytes { bytes in
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count)
            defer { buffer.deallocate() }
            
            let compressedSize = compression_encode_buffer(
                buffer, data.count,
                bytes.bindMemory(to: UInt8.self).baseAddress!, data.count,
                nil, algorithm.algorithm
            )
            
            guard compressedSize > 0 else {
                throw CompressionError.compressionFailed
            }
            
            return Data(bytes: buffer, count: compressedSize)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let compressionTime = endTime - startTime
        
        let compressionRatio = data.count > 0 ? Double(compressedData.count) / Double(data.count) : 0
        
        return CompressionResult(
            originalSize: data.count,
            compressedSize: compressedData.count,
            compressionRatio: compressionRatio,
            algorithm: algorithm,
            compressionTime: compressionTime,
            data: compressedData
        )
    }
    
    /// Decompress data using specified algorithm
    /// - Parameters:
    ///   - compressedData: Compressed data
    ///   - algorithm: Algorithm used for compression
    ///   - expectedSize: Expected size of decompressed data
    /// - Returns: Decompression result
    /// - Throws: Decompression error
    public static func decompress(
        data compressedData: Data,
        using algorithm: CompressionAlgorithm = .lz4,
        expectedSize: Int
    ) throws -> DecompressionResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let decompressedData = try compressedData.withUnsafeBytes { bytes in
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: expectedSize)
            defer { buffer.deallocate() }
            
            let decompressedSize = compression_decode_buffer(
                buffer, expectedSize,
                bytes.bindMemory(to: UInt8.self).baseAddress!, compressedData.count,
                nil, algorithm.algorithm
            )
            
            guard decompressedSize > 0 else {
                throw CompressionError.decompressionFailed
            }
            
            return Data(bytes: buffer, count: decompressedSize)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let decompressionTime = endTime - startTime
        
        return DecompressionResult(
            compressedSize: compressedData.count,
            decompressedSize: decompressedData.count,
            algorithm: algorithm,
            decompressionTime: decompressionTime,
            data: decompressedData
        )
    }
    
    // MARK: - Adaptive Compression
    
    /// Choose the best compression algorithm for given data
    /// - Parameter data: Data to analyze
    /// - Returns: Recommended compression algorithm
    public static func chooseBestAlgorithm(for data: Data) -> CompressionAlgorithm {
        // For small data, use fast compression
        if data.count < 1024 {
            return .lz4
        }
        
        // For medium data, use balanced compression
        if data.count < 10240 {
            return .lzfse
        }
        
        // For large data, analyze content type
        let entropy = calculateEntropy(data)
        
        // High entropy data (already compressed/encrypted) - use fast compression
        if entropy > 7.5 {
            return .lz4
        }
        
        // Low entropy data (text, repetitive) - use better compression
        if entropy < 5.0 {
            return .lzma
        }
        
        // Medium entropy - use balanced compression
        return .lzfse
    }
    
    /// Compress data with automatic algorithm selection
    /// - Parameter data: Data to compress
    /// - Returns: Compression result with optimal algorithm
    /// - Throws: Compression error
    public static func compressAdaptive(data: Data) throws -> CompressionResult {
        let algorithm = chooseBestAlgorithm(for: data)
        return try compress(data: data, using: algorithm)
    }
    
    // MARK: - Batch Compression
    
    /// Compress multiple data chunks efficiently
    /// - Parameters:
    ///   - dataChunks: Array of data chunks to compress
    ///   - algorithm: Compression algorithm to use
    /// - Returns: Array of compression results
    public static func compressBatch(
        dataChunks: [Data],
        using algorithm: CompressionAlgorithm = .lz4
    ) -> [Result<CompressionResult, Error>] {
        return dataChunks.map { data in
            do {
                let result = try compress(data: data, using: algorithm)
                return .success(result)
            } catch {
                return .failure(error)
            }
        }
    }
    
    /// Decompress multiple data chunks efficiently
    /// - Parameters:
    ///   - compressedChunks: Array of compressed data chunks
    ///   - algorithm: Algorithm used for compression
    ///   - expectedSizes: Expected sizes of decompressed data
    /// - Returns: Array of decompression results
    public static func decompressBatch(
        compressedChunks: [Data],
        using algorithm: CompressionAlgorithm = .lz4,
        expectedSizes: [Int]
    ) -> [Result<DecompressionResult, Error>] {
        guard compressedChunks.count == expectedSizes.count else {
            return compressedChunks.map { _ in .failure(CompressionError.invalidParameters) }
        }
        
        return zip(compressedChunks, expectedSizes).map { data, expectedSize in
            do {
                let result = try decompress(data: data, using: algorithm, expectedSize: expectedSize)
                return .success(result)
            } catch {
                return .failure(error)
            }
        }
    }
    
    // MARK: - Utility Methods
    
    /// Calculate entropy of data to determine compressibility
    /// - Parameter data: Data to analyze
    /// - Returns: Entropy value (0-8, higher means less compressible)
    private static func calculateEntropy(_ data: Data) -> Double {
        guard !data.isEmpty else { return 0 }
        
        var frequencies: [UInt8: Int] = [:]
        
        // Count byte frequencies
        for byte in data {
            frequencies[byte, default: 0] += 1
        }
        
        // Calculate entropy
        let dataLength = Double(data.count)
        var entropy: Double = 0
        
        for (_, count) in frequencies {
            let probability = Double(count) / dataLength
            if probability > 0 {
                entropy -= probability * log2(probability)
            }
        }
        
        return entropy
    }
    
    /// Check if data is worth compressing
    /// - Parameters:
    ///   - data: Data to check
    ///   - threshold: Minimum compression ratio to consider worthwhile
    /// - Returns: True if compression is recommended
    public static func shouldCompress(data: Data, threshold: Double = 0.9) -> Bool {
        // Don't compress very small data
        if data.count < 100 {
            return false
        }
        
        // Check entropy - high entropy data won't compress well
        let entropy = calculateEntropy(data)
        return entropy < 7.0
    }
    
    /// Get compression statistics for data
    /// - Parameter data: Data to analyze
    /// - Returns: Compression analysis
    public static func analyzeCompression(data: Data) -> CompressionAnalysis {
        let entropy = calculateEntropy(data)
        let recommendedAlgorithm = chooseBestAlgorithm(for: data)
        let shouldCompress = shouldCompress(data: data)
        
        return CompressionAnalysis(
            dataSize: data.count,
            entropy: entropy,
            recommendedAlgorithm: recommendedAlgorithm,
            shouldCompress: shouldCompress,
            estimatedCompressionRatio: estimateCompressionRatio(entropy: entropy)
        )
    }
    
    private static func estimateCompressionRatio(entropy: Double) -> Double {
        // Rough estimation based on entropy
        if entropy < 3.0 { return 0.3 } // Very compressible
        if entropy < 5.0 { return 0.5 } // Moderately compressible
        if entropy < 7.0 { return 0.7 } // Slightly compressible
        return 0.9 // Not very compressible
    }
}

// MARK: - Supporting Types

/// Compression analysis result
public struct CompressionAnalysis {
    public let dataSize: Int
    public let entropy: Double
    public let recommendedAlgorithm: DataCompression.CompressionAlgorithm
    public let shouldCompress: Bool
    public let estimatedCompressionRatio: Double
    
    public var description: String {
        return """
        Compression Analysis:
        - Data Size: \(dataSize) bytes
        - Entropy: \(String(format: "%.2f", entropy))
        - Recommended Algorithm: \(recommendedAlgorithm.displayName)
        - Should Compress: \(shouldCompress)
        - Estimated Ratio: \(String(format: "%.2f", estimatedCompressionRatio))
        """
    }
}

/// Compression errors
public enum CompressionError: Error, LocalizedError {
    case compressionFailed
    case decompressionFailed
    case invalidParameters
    case insufficientBuffer
    
    public var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Compression operation failed"
        case .decompressionFailed:
            return "Decompression operation failed"
        case .invalidParameters:
            return "Invalid compression parameters"
        case .insufficientBuffer:
            return "Insufficient buffer size for compression"
        }
    }
}

// MARK: - Message Compression Extension

// Note: Message compression extension removed due to RealtimeMessage immutability
// This functionality can be implemented at the application level where
// messages can be properly constructed with compression metadata