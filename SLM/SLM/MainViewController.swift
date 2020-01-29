import UIKit
import Dispatch
import CoreData
import Accelerate
import Foundation
import UserNotifications

struct thresholdKey {
    static var threshold: Float = 0.0
}

class MainViewController: UIViewController {
    
    @IBOutlet weak var minDbLabel: UILabel!
    @IBOutlet weak var averageDbLabel: UILabel!
    @IBOutlet weak var maximumDbLabel: UILabel!
    
    var recordsArray = [Record]()
    
    var minimum: Float = .nan
    var average: Float = .nan
    var maximum: Float = .nan
    var decibel: Float = .nan
    
    var audioInput: AudioInput!
    var decibelArray: [Float] = []
    let sampleRate: Float = 44100.0
    let timer: Timer = Timer()
    let test = GaugeView(frame: CGRect(x: 80, y: 140, width: 256, height: 256))
    
    override var shouldAutorotate: Bool {
        return false
    }
    
    // MARK: Lifecycle functions
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let swipe = UISwipeGestureRecognizer(target: self, action: #selector(swipeLeft(_:)))
        swipe.direction = .left
        
        test.backgroundColor = .clear
        
        self.view.addSubview(test)
        self.view.addGestureRecognizer(swipe)
        
        let audioInputCallback: AudioInputCallback = { (timeStamp, numberOfFrames, samples) -> Void in
            self.decibel = self.obtainDecibelValue(timeStamp: Double(timeStamp), numberOfFrames: Int(numberOfFrames), samples: samples)
            self.decibelArray.append(self.decibel)
            DispatchQueue.main.async {
                self.updateLabels()
            }
        }
        audioInput = AudioInput(audioInputCallback: audioInputCallback, sampleRate: 44100, numberOfChannels: 1)
        audioInput.startRecording()
    }
    
    @objc func updateLabels() {
        self.test.value = decibel
        self.minDbLabel.text = "\(String(format: "%.1f", findMin(in: self.decibelArray)))"
        self.averageDbLabel.text = "\(String(format: "%.1f", findAverage(in: self.decibelArray)))"
        self.maximumDbLabel.text = "\(String(format: "%.1f", findMax(in: self.decibelArray)))"
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: Bar Button Functions
    @IBAction func replayRecording(_ barButtonItem: UIBarButtonItem) {
        audioInput.startRecording()
    }
    
    
    @IBAction func pauseRecording(_ barButtonItem: UIBarButtonItem) {
        audioInput.stopRecording()
    }
    
    @IBAction func refreshRecording(_ barButtonItem: UIBarButtonItem) {
        self.test.value = 0.0
        self.minDbLabel.text = "\(0.0)"
        self.averageDbLabel.text = "\(0.0)"
        self.maximumDbLabel.text = "\(0.0)"
        replayRecording(barButtonItem)
    }
    
    @IBAction func setThreshold(_ barButtonItem: UIBarButtonItem) {
        let alert = UIAlertController(title: "Set Threshold", message: nil, preferredStyle: .alert)
        alert.addTextField(configurationHandler: { (textField) in
            textField.placeholder = "Enter an integer value:"
        })
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (action) in
            thresholdKey.threshold = ((alert.textFields?.first!.text)! as NSString).floatValue
            alert.dismiss(animated: true, completion: nil)
        }))
        self.present(alert, animated: true, completion: nil)
    }

    /// MARK: Swipe gesture function
    
    @objc func swipeLeft(_ gesture: UISwipeGestureRecognizer) {
        switch gesture.direction {
        case .left:
        performSegue(withIdentifier: "swipeLeft", sender: nil)
        default:
        break
        }
    }
    
    /// MARK: Segue functions
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "saveRecord" {
            let recordVC = segue.destination as! RecordTableViewController
            let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
            let record = Record.init(entity: NSEntityDescription.entity(forEntityName: "History", in: context)!, insertInto: context)
            
            record.minimumValue = Float(minDbLabel.text!) ?? 0.0
            record.averageValue = Float(averageDbLabel.text!) ?? 0.0
            record.maximumValue = Float(maximumDbLabel.text!) ?? 0.0
            
            saveNewRecord(record: record)
            
            self.recordsArray.append(record)
            recordVC.recordsArray = self.recordsArray
        }
    }
    
    @IBAction func save(_ sender: UIButton){
        self.performSegue(withIdentifier: "saveRecord", sender: nil)
    }
    
    /// MARK: Callback function
    
    func obtainDecibelValue(timeStamp: Double, numberOfFrames: Int, samples: [Float]) -> Float {
        let fft = FFT(withSize: numberOfFrames, sampleRate: 44100.0)
        fft.windowType = .hanning
        var fftMagnitudes = [Float]()
        fftMagnitudes = fft.fftForward(samples)
        var dbaResult: Float = .nan
        dbaResult = estimateLevel(for: fftMagnitudes, withSampleRate: sampleRate, constant: 70.0)
        return dbaResult
    }
    
    /// MARK: User notification functions
    
    private func createNotification() {
        let content = UNMutableNotificationContent()
        
        content.title = "App"
        content.subtitle = "WARNING!"
        content.body = "Threshold value is passed"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let request = UNNotificationRequest(identifier: "notification_id", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        UNUserNotificationCenter.current().delegate = self
    }
    
    // MARK: Core Data functions
    
    private func saveNewRecord(record: Record) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let context = appDelegate.persistentContainer.viewContext
        
        var index: Int = 0
        
        let entity = NSEntityDescription.entity(forEntityName: "History", in: context)
        let newRecord = [NSManagedObject(entity: entity!, insertInto: context)] as [NSManagedObject]
        
        newRecord[index].setValue(record.minimumValue, forKey: "minimumValue")
        newRecord[index].setValue(record.averageValue, forKey: "averageValue")
        newRecord[index].setValue(record.maximumValue, forKey: "maximumValue")
        index += 1
        
        do {
            try context.save()
        } catch let error {
            print("\(error.localizedDescription)")
        }
    }
}

extension MainViewController: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void)
    {
        completionHandler()
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void)
    {
        completionHandler([.alert, .badge, .sound])
    }
}
