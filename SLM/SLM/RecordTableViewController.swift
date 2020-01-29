import UIKit
import CoreData


class RecordCell: UITableViewCell {
    @IBOutlet weak var maximumValueLabel: UILabel!
    @IBOutlet weak var averageValueLabel: UILabel!
    @IBOutlet weak var minimumValueLabel: UILabel!
}

class RecordTableViewController: UITableViewController, NSFetchedResultsControllerDelegate {
    
    private lazy var fetchedResultsController: NSFetchedResultsController = { () -> NSFetchedResultsController<NSFetchRequestResult> in
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "History")
        let sortDescriptor: [NSSortDescriptor] = []
        fetchRequest.sortDescriptors = sortDescriptor
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let managedObjectContext = appDelegate.persistentContainer.viewContext

        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: managedObjectContext, sectionNameKeyPath: nil, cacheName: nil)
        return fetchedResultsController
    }()
    
    let cellIdentifier: String = "cellID"
    var recordsArray = [Record]()
    
    override var shouldAutorotate: Bool {
        return false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let swipe = UISwipeGestureRecognizer(target: self, action: #selector(swipeRight(_:)))
        swipe.direction = .right
        self.view.addGestureRecognizer(swipe)
        
        recordsArray = fetchAllRecords()
    }
    
    // MARK: Swipe gesture function
    
    @objc func swipeRight(_ gesture: UISwipeGestureRecognizer) {
        switch gesture.direction {
        case .right:
            self.dismiss(animated: true, completion: nil)
        default:
            break
        }
    }
}

extension RecordTableViewController {
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return recordsArray.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as! RecordCell
        cell.minimumValueLabel.text = "\(recordsArray[indexPath.row].minimumValue)"
        cell.averageValueLabel.text = "\(recordsArray[indexPath.row].averageValue)"
        cell.maximumValueLabel.text = "\(recordsArray[indexPath.row].maximumValue)"
        return cell
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let delete = UITableViewRowAction(style: .destructive, title: "Delete") { (action, indexPath) in
            self.recordsArray.remove(at: indexPath.row)
            self.tableView.deleteRows(at: [indexPath], with: .fade)
        }
        delete.backgroundColor = UIColor.red
        return [delete]
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "\tMIN\t\t\t\tAVG\t\t\tMAX"
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        switch editingStyle {
        case .delete:
            let removedRecord = fetchedResultsController.object(at: indexPath) as! NSManagedObject
            let context = fetchedResultsController.managedObjectContext
            context.delete(removedRecord)
            
            do {
                try context.save()
                self.recordsArray.remove(at: indexPath.row)
                tableView.deleteRows(at: [indexPath], with: .fade)
            } catch _ {
                
            }
        default:
            break
        }
    }
}

extension RecordTableViewController {
    public func fetchAllRecords() -> [Record] {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let context = appDelegate.persistentContainer.viewContext
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "History")
        request.returnsObjectsAsFaults = false
        
        do {
            let result = try context.fetch(request)
            return result as! [Record]
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }
}
