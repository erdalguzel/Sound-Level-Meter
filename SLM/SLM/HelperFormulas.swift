import Foundation
import Accelerate

func abs(_ vector: [Float]) -> [Float] {
	var output = [Float](repeating: 0.0, count: vector.count)
	vDSP_vabs(vector, vDSP_Stride(1), &output, vDSP_Stride(1), vDSP_Length(vector.count))
	return output
}

func sqrt(_ vector: [Float]) -> [Float] {
	var tempVector: [Float] = vector
	var n = Int32(vector.count)
	vvsqrtf(&tempVector, vector, &n)
	return tempVector
}

func findMin(in array: [Float]) -> Float {
	var c: Float = .nan
	vDSP_minv(array, vDSP_Stride(1), &c, vDSP_Length(array.count))
	return c
}

func findAverage(in array: [Float]) -> Float {
	var c: Float = .nan
	vDSP_meanv(array, vDSP_Stride(1), &c, vDSP_Length(array.count))
	return c
}

func findMax(in array: [Float]) -> Float {
	var c: Float = .nan
	vDSP_maxv(array, vDSP_Stride(1), &c, vDSP_Length(array.count))
	return c
}

func filterA(_ freq: [Float]) -> [Float] {
	var c1: Float = 12194.0 ** 2
	var c2: Float = 20.6 ** 2
	var c3: Float = 107.7 ** 2
	var c4: Float = 737.9 ** 2
	
	var filteredFreq = [Float](repeating: 0.0, count: freq.count)
	
	var index = 0
	for element in freq {
		if element == 0 {
			filteredFreq[index] = 1e-17
		} else {
			filteredFreq[index] = freq[index]
		}
		index += 1
	}
	
	// Debugging purposes
	
	//print("filteredFreq before squared is \(filteredFreq)")
	filteredFreq = filteredFreq .^ 2
	//print("filteredFreq after squared is \(filteredFreq)")
	
	let stride = vDSP_Stride(1)
	let length = vDSP_Length(filteredFreq.count)
	
	// MARK: Numerator part of A-weighted formula
	var numerator = [Float](repeating: 0.0, count: filteredFreq.count)
	vDSP_vmul(filteredFreq, stride, filteredFreq, stride, &numerator, vDSP_Stride(1), length)
	vDSP_vsadd(numerator, stride, &c1, &numerator, stride, length)
	
	// MARK: Denominator part of A-weighted formula
	var expr1 = [Float](repeating: 0.0, count: numerator.count)
	var expr2 = [Float](repeating: 0.0, count: numerator.count)
	
	vDSP_vsadd(filteredFreq, stride, &c2, &expr1, stride, length)
	vDSP_vsadd(filteredFreq, stride, &c1, &expr2, stride, length)
	
	var part1 = [Float](repeating: 0.0, count: numerator.count)
	vDSP_vmul(expr1, stride, expr2, stride, &part1, stride, length)
	
	var expr3 = [Float](repeating: 0.0, count: numerator.count)
	var expr4 = [Float](repeating: 0.0, count: numerator.count)
	
	vDSP_vsadd(filteredFreq, stride, &c3, &expr3, stride, length)
	vDSP_vsadd(filteredFreq, stride, &c4, &expr4, stride, length)
	
	var part2 = [Float](repeating: 0.0, count: numerator.count)
	vDSP_vmul(expr3, stride, expr4, stride, &part2, stride, length)
	part2 = sqrt(part2)
	
	var denominator = [Float](repeating: 0.0, count: numerator.count)
	vDSP_vmul(part1, stride, part2, stride, &denominator, stride, length)
	
	var A = [Float](repeating: 0.0, count: numerator.count)
	vDSP_vdiv(denominator, stride, numerator, stride, &A, stride, length)
	return A
}

func estimateLevel(for x: [Float], withSampleRate Fs: Float, constant C: Float) -> Float {
	var X: [Float] = abs(x)
	var index = 0
	
	// Add an offset to prevent log10'ing 0
	for element in X {
		if element == 0 {
			X[index] = 1e-17
		}
		index = index + 1
	}
	
	// Retain frequencies below Nyquist rate to prevent distortion
	let length: Int = X.count
	
	let f = [Int](0...(length - 1)) .* (Int(Fs) / length)
	var tempF = [Float]()
	var tempX = [Float]()
	
	for (index, value) in f.enumerated() {
		if value < Fs/2.0 {
			tempX.append(X[index])
			tempF.append(f[index])
		}
	}
    
	// Apply A-weighted filter
	var A = [Float](repeating: 0.0, count: tempF.count)
	A = filterA(tempF)
	let dBA = calculateDBA(x: X, Fs: Fs, constant: C)
	return dBA
}

func calculateDBA(x: [Float], Fs: Float, constant: Float) -> Float {
	var sum: Float = 0.0
	for index in 0..<x.count {
		sum = sum + (x[index] ** 2)
	}
	
	let totalEnergy = sum
	let meanEnergy = totalEnergy * Fs / Float(x.count)
	let dBA = 10.0 * log10f(meanEnergy) + constant
	return (dBA * 10).rounded() / 10
}
