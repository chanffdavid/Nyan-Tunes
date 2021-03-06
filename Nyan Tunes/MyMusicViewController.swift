//
//  MyMusicViewController.swift
//  Nyan Tunes
//
//  Created by Pushkar Sharma on 27/09/2016.
//  Copyright © 2016 thePsguy. All rights reserved.
//

import UIKit
import CoreData

class MyMusicViewController: UIViewController {

    
    @IBOutlet weak var audioTableView: UITableView!
    @IBOutlet weak var miniPlayer: MiniPlayerView!
    
    var audioManager = AudioManager.sharedInstance
    let refreshControl = UIRefreshControl()
    var offlineMode = false
    
    var docVC: UIDocumentInteractionController?
    
    // Core Data
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext
    }
    
    var files = [AudioFile]()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        if offlineMode {
            let button = UIButton(frame: CGRect(x: 0, y: 0, width: 44, height: 25))
            button.setTitle("Done", for: .normal)
            button.addTarget(self, action: #selector(dismissSelf), for: .touchUpInside)
            self.navigationItem.rightBarButtonItem = UIBarButtonItem.init(customView: button)
        }
        
        miniPlayer.delegate = self

        audioTableView.delegate = self
        audioTableView.dataSource = self
        
        refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
        refreshControl.addTarget(self, action: #selector(self.refreshAudio), for: UIControlEvents.valueChanged)
        audioTableView.addSubview(refreshControl)
        
        miniPlayer.makeTranslucent()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        refreshAudio()
        miniPlayer.refreshStatus()
        let topInset = (self.navigationController?.navigationBar.frame.height)! + UIApplication.shared.statusBarFrame.height
        let tabBarHeight = self.tabBarController?.tabBar.frame.height == nil ? 0 : (self.tabBarController?.tabBar.frame.height)!
        let bottomInset = self.miniPlayer.frame.height + tabBarHeight
        self.audioTableView.contentInset = UIEdgeInsets(top: topInset, left: 0, bottom: bottomInset, right: 0)
    }
    
    @IBAction func refreshAudio(){
                files = fetchAllAudio()
                self.audioManager.downloadedAudioItems = files
                self.audioTableView.reloadData()
                self.refreshControl.endRefreshing()
            }
    
    func dismissSelf() {
        print("Called")
        self.dismiss(animated: true, completion: nil)
    }
    
    func fetchAllAudio() -> [AudioFile] {
        var result = [AudioFile]()
        sharedContext.performAndWait {
            let fetchRequest: NSFetchRequest<AudioFile> = AudioFile.fetchRequest()
            do {
                result = try self.sharedContext.fetch(fetchRequest)
            } catch {
                print("error in fetch")
            }
        }
        return result
    }


    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

extension MyMusicViewController: UITableViewDelegate, UITableViewDataSource{
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return files.count
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath) as! AudioTableViewCell
        audioManager.playNow(obj: cell)
        miniPlayer.refreshStatus()
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "audioCell") as! AudioTableViewCell
        let file = files[indexPath.row]
        cell.title.text = file.title!
        cell.artist.text = file.artist!
        cell.audioData = file.audioData! as Data
        cell.url = URL(string: file.url!)
        cell.duration = file.duration
        return cell
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        var actions: [UITableViewRowAction] = []
        
        let deleteAction = UITableViewRowAction(style: .default, title: "Delete") { (action, actionIndex) in
            self.rowActionHandler(action: action, indexPath: indexPath)
        }
        
        let exportAction = UITableViewRowAction(style: .default , title: "Export") { (action, actionIndex) in
            self.rowActionHandler(action: action, indexPath: indexPath)
        }
        
        exportAction.backgroundColor = UIColor(red: 0.66, green: 0.72, blue: 0.33, alpha: 1.0)
        
        actions.append(deleteAction)
        actions.append(exportAction)
        return actions
    }
    
    func rowActionHandler(action: UITableViewRowAction, indexPath: IndexPath) {
        if action.title == "Delete" {
            let file = files[indexPath.row]
            sharedContext.delete(file)
            try! sharedContext.save()
            refreshAudio()
        } else if action.title == "Export"{
            let file = files[indexPath.row]
            let fileName = file.title!  + " " + String(file.id) + ".mp3"
            let url = URL(fileURLWithPath: NSTemporaryDirectory().appending(fileName))
            let data = file.audioData as! Data
            
            // write data
            do { try data.write(to: url)} catch{
                print(error)
            }
            
            self.docVC = UIDocumentInteractionController(url: url)
            self.docVC?.delegate = self
            self.docVC!.presentOpenInMenu(from: (self.miniPlayer.frame), in: self.view, animated: true)
//            self.present(activityVC, animated: true, completion: nil)
            }
        }
}

extension MyMusicViewController: MiniPlayerViewDelegate{
        func togglePlay() {
            if audioManager.isPlaying {
                audioManager.pausePlay()
            }else{
                audioManager.resumePlay()
            }
            miniPlayer.refreshStatus()
        }
}

extension MyMusicViewController: UIDocumentInteractionControllerDelegate {

    func documentInteractionControllerDidDismissOpenInMenu(_ controller: UIDocumentInteractionController) {
        if let url = controller.url {
            let fileManager = FileManager.default
            do {
                try fileManager.removeItem(at: url)
            }
            catch let error {
                print("Ooops! Something went wrong: \(error)")
            }
        }
    }
    
}
