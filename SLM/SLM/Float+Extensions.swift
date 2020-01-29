import Foundation

infix operator **
infix operator ./
infix operator .*.

extension Float {
	
	// MARK: Custom operators
	
	/**
	- Custom element-wise power operator for ```Float``` data type
	
	- Author:
	Erdal Guzel
	
	- parameters:
		- lhs: Left hand side of the operator
		-  rhs: Right hand side of the operator
	
	- returns:
	An array whose power is taken to the value which is determined by ```rhs``` operator
	*/
	static func **(_ lhs: Float, _ rhs: Int) -> Float {
		var result: Float = 1.0
		
		for _ in 0..<rhs {
			result *= lhs
		}
		return result
	}
}

extension Array where Element == Float {
	/**
	- Custom element-wise division operator for ```Float``` array data type.
	
	- Author:
	Erdal Guzel
	
	- parameters:
		- lhs: Left hand side of the operator
		-  rhs: Right hand side of the operator
	
	- returns:
	An array whose power is taken to the value which is determined by ```rhs``` operator.
	
	- Important:
	This operator does not perform this operation in-place.
	*/
	
	static func ./(_ lhs: [Float], _ rhs: [Float]) -> [Float] {
		var resultArray = [Float](repeating: 0.0, count: lhs.count)
		
		for index in 0..<lhs.count {
			resultArray[index] = lhs[index] / rhs[index]
		}
		return resultArray
	}
	
	/**
	- Custom element-wise array multiplication operator for ```Float Array``` data type
	
	- Author:
	Erdal Guzel
	
	- parameters:
		- lhs: Left hand side of the operator
		-  rhs: Right hand side of the operator
	
	- returns:
	An array whose values are multiplied by two input array.
	*/
	static func .*.(_ lhs: [Float], _ rhs: [Float]) -> [Float] {
		var resultArray = [Float](repeating: 0.0, count: lhs.count)
		
		for index in 0..<lhs.count {
			resultArray[index] = lhs[index] * rhs[index]
		}
		return resultArray
	}
}
