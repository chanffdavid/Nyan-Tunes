//
//  MyMusicViewController.swift
//  Nyan Tunes
//
//  Created by Pushkar Sharma on 26/09/2016.
//  Copyright © 2016 thePsguy. All rights reserved.
//

import UIKit
import VKSdkFramework
import AVFoundation
import CoreData

class ProfileMusicViewController: UIViewController {

    @IBOutlet weak var audioTableView: UITableView!
    @IBOutlet weak var miniPlayer: MiniPlayerView!
    
    let vkManager: VKClient = {
        return VKClient.sharedInstance()
    }()
    
    var files = [AudioFile]()
    var audioManager = AudioManager.sharedInstance
    let refreshControl = UIRefreshControl()
    
    // Core Data
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext
    }
    
    var downloadManager:DownloadManager = {
        return DownloadManager.sharedInstance()
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
       
        downloadManager.downloadDelegate = self
        
        miniPlayer.delegate = self
        refreshAudio()
        audioTableView.delegate = self
        audioTableView.dataSource = self
        
        refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
        refreshControl.addTarget(self, action: #selector(self.refreshAudio), for: UIControlEvents.valueChanged)
        audioTableView.addSubview(refreshControl)
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        miniPlayer.refreshStatus()
    }

    @IBAction func refreshAudio(){
        files = fetchAllAudio()
        vkManager.getUserAudio(completion: {error, audioItems in
            if error != nil {
                print(error)
            }else{
                self.audioManager.profileAudioItems = audioItems!
                self.audioTableView.reloadData()
                self.refreshControl.endRefreshing()
            }
        })
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

extension ProfileMusicViewController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return audioManager.profileAudioItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "audioCell") as! AudioTableViewCell
        let audioItem = audioManager.profileAudioItems[indexPath.row]
        
        if(audioItem.url != nil){
            var showDownloadControls = false
            var downloadable = true
            for file in files{
                if Int(audioItem.id) == Int(file.id){
                    downloadable = false
                    cell.audioData = file.audioData! as Data
                }
            }
            
            if let download = downloadManager.activeDownloads[audioItem.url!] {
                showDownloadControls = true
                cell.progressView.progress = download.progress
                cell.progressLabel.text = "Downloading..."
            }
            
            cell.cancelButton.isHidden = !showDownloadControls
            cell.cancelButton.isEnabled = showDownloadControls
            cell.downloadButton.isHidden = !downloadable || showDownloadControls
            cell.progressView.isHidden = !showDownloadControls
            cell.progressLabel.isHidden = !showDownloadControls
        }
        
        cell.trackDelegate = self
        cell.title.text = audioItem.title!
        cell.artist.text = audioItem.artist!
        cell.duration = audioItem.duration.stringValue
        cell.url = URL(string: audioItem.url)
        return cell
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        var actions: [UITableViewRowAction] = []
        
        let download = UITableViewRowAction(style: .default, title: "Delete") { (action, actionIndex) in
            self.rowActionHandler(action: action, indexPath: indexPath)
        }
        
        actions.append(download)
        
        return actions
    }
    
    func rowActionHandler(action: UITableViewRowAction, indexPath: IndexPath) {
        if action.title == "Delete" {
            vkManager.deleteUserAudio(audioID: audioManager.profileAudioItems[indexPath.row].id.stringValue, completion: { (error, res) in
                if error != nil {
                    print(error)
                }else{
                    print("RESPONSE:", res)
                    self.refreshAudio()
                }
            })
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath) as! AudioTableViewCell
        audioManager.playNow(obj: cell)
        miniPlayer.refreshStatus()
    }
    
    
}

extension ProfileMusicViewController: MiniPlayerViewDelegate{
    func togglePlay() {
        if audioManager.isPlaying {
            audioManager.pausePlay()
        }else{
            audioManager.resumePlay()
        }
        miniPlayer.refreshStatus()
    }
}

extension ProfileMusicViewController: URLSessionDownloadDelegate{

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        // 1
        if let downloadUrl = downloadTask.originalRequest?.url?.absoluteString,
            let download = downloadManager.activeDownloads[downloadUrl] {
            // 2
            download.progress = Float(totalBytesWritten)/Float(totalBytesExpectedToWrite)
            // 3
            let totalSize = ByteCountFormatter.string(fromByteCount: totalBytesExpectedToWrite, countStyle: ByteCountFormatter.CountStyle.binary)
            // 4
            let trackIndex = downloadManager.trackIndexForDownloadTask(downloadTask: downloadTask)
            if (trackIndex != nil){
                let audioCell = audioTableView.cellForRow(at: IndexPath(row: trackIndex!, section: 0)) as? AudioTableViewCell
                DispatchQueue.main.async {
                    audioCell!.progressView.progress = download.progress
                    audioCell!.progressLabel.text =  String(format: "%.1f%% of %@",  download.progress * 100, totalSize)
                }
            }
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
            let trackIndex = downloadManager.trackIndexForDownloadTask(downloadTask: downloadTask)
            if (trackIndex != nil){
                let track = audioManager.profileAudioItems[trackIndex!]
                let _ = AudioFile(id: track.id as Int, title: track.title, artist: track.artist, url: track.url, audioData: try! Data.init(contentsOf: location), duration: track.duration.stringValue, context: sharedContext)
                do{
                    try sharedContext.save()
                } catch { print("CoreData save error") }
            }
        DispatchQueue.main.async {
            self.downloadManager.activeDownloads[self.audioManager.profileAudioItems[trackIndex!].url] = nil
            self.audioTableView.reloadRows(at: [IndexPath(row: trackIndex!, section: 0)], with: .none)
        }
    }
}


extension ProfileMusicViewController: AudioTableViewCellDelegate{
    
    func downloadTapped(onCell: AudioTableViewCell) {
        print(self.audioManager.profileAudioItems.count)
        if let indexPath = audioTableView.indexPath(for: onCell) {
            let track = audioManager.profileAudioItems[indexPath.row]
            downloadManager.startDownload(track: track)
            audioTableView.reloadRows(at: [IndexPath(row: indexPath.row, section: 0)], with: .none)
        }
        
    }
    
    func cancelTapped(onCell: AudioTableViewCell) {
        if let indexPath = audioTableView.indexPath(for: onCell) {
            let track = audioManager.profileAudioItems[indexPath.row]
            downloadManager.cancelDownload(track: track)
            audioTableView.reloadRows(at: [IndexPath(row: indexPath.row, section: 0)], with: .none)
        }
    }
}