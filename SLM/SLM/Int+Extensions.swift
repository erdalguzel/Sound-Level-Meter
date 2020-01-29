import Foundation
import Accelerate

infix operator .^
infix operator .+
infix operator .*

extension Int {
	
	// MARK: Custom operators
	
	/**
	- Custom element-wise power operator
	
	- Author:
	Erdal Guzel
	
	- parameters:
		- lhs: Left hand side of the operator
		-  rhs: Right hand side of the operator
	
	- returns:
	An array whose power is taken to the value which is determined by ```rhs``` operator
	*/
	static func .^(_ lhs: [Float], _ rhs: Int) -> [Float] {
		var array = [Float](repeating: 0.0, count: lhs.count)
		
		for index in 0..<array.count {
			array[index] = pow(lhs[index], Float(rhs))
		}
		return array
	}
	
	/**
	- Custom element-wise addition operator
	
	- Author:
	Erdal Guzel
	
	- parameters:
		- lhs: Left hand side of the operator
		-  rhs: Right hand side of the operator
	
	- returns:
	An array whose power is taken to the value which is determined by ```rhs``` operator
	*/
	static func .+(_ lhs: [Float], _ rhs: Int) -> [Float] {
		var array = [Float](repeating: 0.0, count: lhs.count)
		
		for index in 0..<array.count {
			array[index] = lhs[index] + Float(rhs)
		}
		
		return array
	}
	
	/**
	- Custom element-wise multiplication operator
	
	- Author:
	Erdal Guzel
	
	- parameters:
		- lhs: Left hand side of the operator
		-  rhs: Right hand side of the operator
	
	- returns:
	An array whose elements are multiplied with value determined by ```rhs``` operator.
	*/
	static func .*(_ lhs: [Int], _ rhs: Int) -> [Float] {
		var array = [Float](repeating: 0.0, count: lhs.count)
		
		for index in 0..<array.count {
			array[index] = Float(lhs[index]) * Float(rhs)
		}
		
		return array
	}
}
