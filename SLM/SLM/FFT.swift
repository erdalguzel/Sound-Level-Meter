import Foundation
import Accelerate

@objc enum FFTWindowType: NSInteger {
    case none
    case hanning
    case hamming
}

@objc class FFT: NSObject {
    
    /// The length of the sample buffer we'll be analyzing.
    private(set) var size: Int
    
    /// The sample rate provided at init time.
    private(set) var sampleRate: Float
    
    /// The Nyquist frequency is ```sampleRate``` / 2
    var nyquistFrequency: Float {
        get {
            return sampleRate / 2.0
        }
    }
    
    // After performing the FFT, contains size/2 magnitudes, one for each frequency band.
    private var magnitudes: [Float] = []
    
    /// Supplying a window type (hanning or hamming) smooths the edges of the incoming waveform and reduces output errors from the FFT function.
	var windowType: FFTWindowType = .none
    
    private var halfSize: Int
    private var log2Size: Int
    private var window: [Float] = []
    private var fftSetup: FFTSetup
    private var hasPerformedFFT: Bool = false
    private var complexBuffer: DSPSplitComplex!
    
    /// Instantiate the FFT.
    /// - Parameter withSize: The length of the sample buffer we'll be analyzing. Must be a power of 2. The resulting ```magnitudes``` are of length ```inSize/2```.
    /// - Parameter sampleRate: Sampling rate of the provided audio data.
    init(withSize inSize:Int, sampleRate inSampleRate: Float) {
        
        let sizeFloat: Float = Float(inSize)
        
        self.sampleRate = inSampleRate
        
        // Check if the size is a power of two
        let lg2 = logbf(sizeFloat)
        assert(remainderf(sizeFloat, powf(2.0, lg2)) == 0, "size must be a power of 2")
        
        self.size = inSize
        self.halfSize = inSize / 2
        
        // create fft setup
        self.log2Size = Int(log2f(sizeFloat))
        self.fftSetup = vDSP_create_fftsetup(UInt(log2Size), FFTRadix(FFT_RADIX2))!
        
        // Init the complexBuffer
        var real = [Float](repeating: 0.0, count: self.halfSize)
        var imaginary = [Float](repeating: 0.0, count: self.halfSize)
        self.complexBuffer = DSPSplitComplex(realp: &real, imagp: &imaginary)
	}
    deinit {
        // destroy the fft setup object
        vDSP_destroy_fftsetup(fftSetup)
    }
    
    /// Perform a forward FFT on the provided single-channel audio data. When complete, the instance can be queried for information about the analysis or the magnitudes can be accessed directly.
    /// - Parameter inMonoBuffer: Audio data in mono format
    func fftForward(_ inBuffer: [Float]) -> [Float] {
        
        var analysisBuffer = inBuffer
        
        // If we have a window, apply it now. Since 99.9% of the time the window array will be exactly the same, an optimization would be to create it once and cache it, possibly caching it by size.
        if self.windowType != .none {
            if self.window.isEmpty {
                self.window = [Float](repeating: 0.0, count: size)
                
                switch self.windowType {
                case .hamming:
                    vDSP_hamm_window(&self.window, UInt(size), 0)
                case .hanning:
                    vDSP_hann_window(&self.window, UInt(size), Int32(vDSP_HANN_NORM))
                default:
                    break
                }
            }
            
            // Apply the window
            vDSP_vmul(inBuffer, 1, self.window, 1, &analysisBuffer, 1, UInt(inBuffer.count))
        }
        
        // Doing the job of vDSP_ctoz.
        var realp = [Float]()
        var imagp = [Float]()
        for (idx, element) in analysisBuffer.enumerated() {
            if idx % 2 == 0 {
                realp.append(element)
            } else {
                imagp.append(element)
            }
        }
        self.complexBuffer = DSPSplitComplex(realp: UnsafeMutablePointer(mutating: realp), imagp: UnsafeMutablePointer(mutating: imagp))
        
        // Perform a forward FFT
        vDSP_fft_zrip(self.fftSetup, &(self.complexBuffer!), 1, UInt(self.log2Size), Int32(FFT_FORWARD))
        
        // Store and square (for better visualization & conversion to db) the magnitudes
        self.magnitudes = [Float](repeating: 0.0, count: self.halfSize)
        vDSP_zvmags(&(self.complexBuffer!), vDSP_Stride(1), &self.magnitudes, vDSP_Stride(1), UInt(self.halfSize))
		return magnitudes
    }
}
