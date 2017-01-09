//
//  FileListViewController.swift
//  AudioLogger-iOS
//
//  Created by Bryan on 1/8/17.
//  Copyright © 2017 bcattle. All rights reserved.
//

import UIKit
import AVFoundation
//import EZAudioiOS

class FileListViewController: UIViewController {
    @IBOutlet weak var tableView:UITableView!
    @IBOutlet weak var deleteButton:UIButton!
    @IBOutlet weak var shareButton:UIButton!
    @IBOutlet weak var selectButton:UIButton!
    var files:[URL]?
    var allSelected = false
    var player:AVAudioPlayer?
    var playingIndexPath:IndexPath?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.setEditing(true, animated: false)
        updateFileList()
    }
    
    func updateFileList() {
        files = getFiles()
        tableView.reloadData()
        updateButtonVisibility()
    }
    
    func getFiles() -> [URL] {
        let documentsUrl =  FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        do {
            // Get the directory contents urls (including subfolders urls)
            let directoryContents = try FileManager.default.contentsOfDirectory(at: documentsUrl, includingPropertiesForKeys: nil, options: [])
            return directoryContents
            
        } catch let error as NSError {
            print(error.localizedDescription)
            return []
        }
    }
    
    func getSelectedURLs() -> [URL] {
        if let selected = tableView.indexPathsForSelectedRows {
            return selected.map { files![$0.row] }
        } else {
            return []
        }
    }
    
    func deleteFiles(at urls:[URL]) {
        for url in urls {
            do {
                try FileManager.default.removeItem(at: url)
            } catch let error {
                print("Error deleting <\(url)>: \(error)")
            }
        }
        // Done!
        updateFileList()
    }
    
    @IBAction func backButtonTapped(sender:UIButton) {
        self.presentingViewController?.dismiss(animated: true, completion: nil)
    }

    @IBAction func shareButtonTapped(sender:UIButton) {
        let shareVC = UIActivityViewController(activityItems: getSelectedURLs(), applicationActivities: nil)
        present(shareVC, animated: false)
    }
    
    @IBAction func deleteButtonTapped(sender:UIButton) {
        let selected = getSelectedURLs()
        let alert = UIAlertController(title: "Are you sure?", message: "Do you want to delete \(selected.count) files?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Yes", style: .destructive, handler: { (action) in
            self.deleteFiles(at: selected)
        }))
        alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: { (action) in
            
        }))
        present(alert, animated: true)
    }
    
    @IBAction func selectButtonTapped(sender:UIButton) {
        let totalRows = tableView.numberOfRows(inSection: 0)
        for row in 0..<totalRows {
            if allSelected {
                tableView.deselectRow(at:IndexPath(row: row, section: 0), animated: false)
                UIView.performWithoutAnimation {
                    selectButton.setTitle("Select All", for: .normal)
                }

            } else {
                tableView.selectRow(at: IndexPath(row: row, section: 0), animated: false, scrollPosition: .none)
                UIView.performWithoutAnimation {
                    selectButton.setTitle("Select None", for: .normal)
                }
            }
        }
        allSelected = !allSelected
        updateButtonVisibility()
    }
}

extension FileListViewController:UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let files = files {
            return files.count
        } else {
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FileCell", for: indexPath) as! FileCell
        cell.backgroundColor = UIColor.clear
        cell.label.text = files![indexPath.row].lastPathComponent
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        updateButtonVisibility()
        updatePlaybackForIndexPath(indexPath: indexPath)
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        updateButtonVisibility()
        updatePlaybackForIndexPath(indexPath: indexPath)
    }
    
    func updateButtonVisibility() {
        if let selectedRows = tableView.indexPathsForSelectedRows {
            UIView.performWithoutAnimation {
                deleteButton.setTitle("Delete (\(selectedRows.count))", for: .normal)
                shareButton.setTitle("Share (\(selectedRows.count))", for: .normal)
            }
            UIView.animate(withDuration: 0.3, animations: {
                self.deleteButton.alpha = 1
                self.shareButton.alpha = 1
            })
        } else {
            UIView.animate(withDuration: 0.3, animations: {
                self.deleteButton.alpha = 0
                self.shareButton.alpha = 0
            })
        }
    }
    
    func updatePlaybackForIndexPath(indexPath:IndexPath) {
        player?.pause()
        if indexPath != playingIndexPath {
//            player?.pause()
//        } else {
            if let files = files {
                do {
                    try player = AVAudioPlayer(contentsOf: files[indexPath.row])
                    player!.play()
                } catch let error {
                    print("Error trying to play: \(error)")
                }
//                player.
//                let file = EZAudioFile(url: files[indexPath.row])
//                player?.playAudioFile(file)
//                playingIndexPath = indexPath
            }
        }
    }
    
//    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
//        return []
//    }
}
