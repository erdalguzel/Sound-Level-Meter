import Foundation
import CoreData

class Record: NSManagedObject {
	var minimumValue: Float = .nan
	var averageValue: Float = .nan
	var maximumValue: Float = .nan
}
