import AVFoundation

typealias AudioInputCallback = (
    _ timeStamp: Double,
    _ numberOfFrames: Int,
    _ samples: [Float]
    ) -> Void

/// AudioInput sets up an audio input session and notifies when new buffer data is available.
class AudioInput: NSObject {
    private(set) var audioUnit: AudioUnit!
    let audioSession : AVAudioSession = AVAudioSession.sharedInstance()
    var sampleRate: Float
    var numberOfChannels: Int
    
    
    private let outputBus: UInt32 = 0
    private let inputBus: UInt32 = 1
    private var audioInputCallback: AudioInputCallback!

    /// Instantiate a AudioInput object.
    /// - Parameter audioInputCallback: Invoked when audio data is available.
    /// - Parameter sampleRate: The sample rate to set up the audio session with.
    /// - Parameter numberOfChannels: The number of channels to set up the audio session with.
    
    init(audioInputCallback callback: @escaping AudioInputCallback, sampleRate: Float = 44100.0, numberOfChannels: Int = 1) {
        self.sampleRate = sampleRate
        self.numberOfChannels = numberOfChannels
        audioInputCallback = callback
    }

    /// Start recording
    func startRecording() {
        do {
            if self.audioUnit == nil {
                setupAudioSession()
                setupAudioUnit()
			}
            try self.audioSession.setActive(true)
            var osErr: OSStatus = 0
            
            osErr = AudioUnitInitialize(self.audioUnit)
            assert(osErr == noErr, "*** AudioUnitInitialize err \(osErr)")
            osErr = AudioOutputUnitStart(self.audioUnit)
            assert(osErr == noErr, "*** AudioOutputUnitStart err \(osErr)")
        } catch {
            print("*** startRecording error: \(error)")
        }
    }
    
    /// Stop recording.
    func stopRecording() {
        do {
            var osErr: OSStatus = 0
            
            osErr = AudioUnitUninitialize(self.audioUnit)
            assert(osErr == noErr, "*** AudioUnitUninitialize err \(osErr)")
            
            try self.audioSession.setActive(false)
        } catch {
            print("*** error: \(error)")
        }
    }
    
    private let recordingCallback: AURenderCallback = { (inRefCon,
		ioActionFlags,
		inTimeStamp,
		inBusNumber,
		inNumberFrames,
		ioData) -> OSStatus in
        
        let audioInput = unsafeBitCast(inRefCon, to: AudioInput.self)
        var osErr: OSStatus = 0
        
        // We've asked CoreAudio to allocate buffers for us, so just set mData to nil and it will be populated on AudioUnitRender().
        var bufferList = AudioBufferList(
            mNumberBuffers: 1,
            mBuffers: AudioBuffer(
                mNumberChannels: UInt32(audioInput.numberOfChannels),
                mDataByteSize: 4,
                mData: nil))
        
        osErr = AudioUnitRender(audioInput.audioUnit,
            ioActionFlags,
            inTimeStamp,
            inBusNumber,
            inNumberFrames,
            &bufferList)
        assert(osErr == noErr, "*** AudioUnitRender err \(osErr)")
        
        // Move samples from mData into our native [Float] format.
        var monoSamples = [Float]()
        let ptr = bufferList.mBuffers.mData?.assumingMemoryBound(to: Float.self)
        monoSamples.append(contentsOf: UnsafeBufferPointer(start: ptr, count: Int(inNumberFrames)))

        // Not compatible with Obj-C...
        audioInput.audioInputCallback(inTimeStamp.pointee.mSampleTime / Double(audioInput.sampleRate),
                                      Int(inNumberFrames),
                                      monoSamples)
        
        return 0
    }
    
    private func setupAudioSession() {
		guard audioSession.availableCategories.contains(.record) else {
            print("can't record! bailing.")
            return
        }
        
        do {
			try audioSession.setCategory(.record, mode: .measurement, options: .defaultToSpeaker)
            try audioSession.setPreferredSampleRate(Double(sampleRate))
            
            // Docs say that 0.125 buffer duration at 44.1 kHz will give us 256 samples
			// and 0.93 buffer duration at 44.1 kHz will give us 4096 samples.
			let bufferDuration: TimeInterval = 1.0
			try audioSession.setPreferredIOBufferDuration(bufferDuration)
        } catch {
            print("*** audioSession error: \(error)")
        }
    }
    
    private func setupAudioUnit() {
        var componentDesc:AudioComponentDescription = AudioComponentDescription(
            componentType: OSType(kAudioUnitType_Output),
            componentSubType: OSType(kAudioUnitSubType_RemoteIO),
            componentManufacturer: OSType(kAudioUnitManufacturer_Apple),
            componentFlags: 0,
            componentFlagsMask: 0)
        
        var osErr: OSStatus = 0
        
        // Get an audio component matching our description.
        let component: AudioComponent! = AudioComponentFindNext(nil, &componentDesc)
        assert(component != nil, "Couldn't find a default component")
        
        // Create an instance of the AudioUnit
        var tempAudioUnit: AudioUnit?
        osErr = AudioComponentInstanceNew(component, &tempAudioUnit)
        self.audioUnit = tempAudioUnit
        
        assert(osErr == noErr, "*** AudioComponentInstanceNew err \(osErr)")
        
        // Enable I/O for input.
        var one:UInt32 = 1
        
        osErr = AudioUnitSetProperty(audioUnit,
            kAudioOutputUnitProperty_EnableIO,
            kAudioUnitScope_Input,
            inputBus,
            &one,
            UInt32(MemoryLayout<UInt32>.size))
        assert(osErr == noErr, "*** AudioUnitSetProperty err \(osErr)")
        
        osErr = AudioUnitSetProperty(audioUnit,
            kAudioOutputUnitProperty_EnableIO,
            kAudioUnitScope_Output,
            outputBus,
            &one,
            UInt32(MemoryLayout<UInt32>.size))
        assert(osErr == noErr, "*** AudioUnitSetProperty err \(osErr)")
        
        // Set format to 32 bit, floating point, linear PCM
        var streamFormatDesc:AudioStreamBasicDescription = AudioStreamBasicDescription(
            mSampleRate:        Double(sampleRate),
            mFormatID:          kAudioFormatLinearPCM,
            mFormatFlags:       kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved, // floating point data - docs say this is fastest
            mBytesPerPacket:    4,
            mFramesPerPacket:   1,
            mBytesPerFrame:     4,
            mChannelsPerFrame:  UInt32(self.numberOfChannels),
            mBitsPerChannel:    4 * 8,
            mReserved: 0
        )
        
        // Set format for input and output busses
        osErr = AudioUnitSetProperty(audioUnit,
            kAudioUnitProperty_StreamFormat,
            kAudioUnitScope_Input, outputBus,
            &streamFormatDesc,
            UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
        assert(osErr == noErr, "*** AudioUnitSetProperty err \(osErr)")
        
        osErr = AudioUnitSetProperty(audioUnit,
            kAudioUnitProperty_StreamFormat,
            kAudioUnitScope_Output,
            inputBus,
            &streamFormatDesc,
            UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
        assert(osErr == noErr, "*** AudioUnitSetProperty err \(osErr)")
        
        // Set up our callback.
        var inputCallbackStruct = AURenderCallbackStruct(inputProc: recordingCallback, inputProcRefCon: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))
        osErr = AudioUnitSetProperty(audioUnit,
            AudioUnitPropertyID(kAudioOutputUnitProperty_SetInputCallback),
            AudioUnitScope(kAudioUnitScope_Global),
            inputBus,
            &inputCallbackStruct,
            UInt32(MemoryLayout<AURenderCallbackStruct>.size))
        assert(osErr == noErr, "*** AudioUnitSetProperty err \(osErr)")
        
        // Ask CoreAudio to allocate buffers for us on render. (This is true by default but just to be explicit about it...)
        osErr = AudioUnitSetProperty(audioUnit,
            AudioUnitPropertyID(kAudioUnitProperty_ShouldAllocateBuffer),
            AudioUnitScope(kAudioUnitScope_Output),
            inputBus,
            &one,
            UInt32(MemoryLayout<UInt32>.size))
        assert(osErr == noErr, "*** AudioUnitSetProperty err \(osErr)")
    }
}
