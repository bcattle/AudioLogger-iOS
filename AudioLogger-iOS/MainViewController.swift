//
//  MainViewController.swift
//  AudioLogger-iOS
//
//  Created by Bryan on 1/1/17.
//  Copyright © 2017 bcattle. All rights reserved.
//

import UIKit
import AVFoundation

class MainViewController: UIViewController {
    @IBOutlet weak var tagContainerView:UIView!
    @IBOutlet weak var idContainerView:UIView!
    var encoder:ALOpusEncoder?
    var fileUrl:URL?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] (granted) in
            if granted {
                var url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                url.appendPathComponent("test.opus")
                self?.fileUrl = url
                self?.encoder = ALOpusEncoder(filename: url.path)
                self?.encoder?.startWriting()
                print("done")
            } else {
                print("Error: Need permission to record audio")
            }
        }        
    }
    
    @IBAction func stopButtonTapped(sender: UIButton) {
        encoder?.stopWriting()
    }
    
    @IBAction func shareButtonTapped(sender: UIButton) {
        if let url = fileUrl {
            let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            present(activityViewController, animated: true, completion: nil)
        }
    }
    
    @IBAction func segmentTapped(sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == 0 {
            self.tagContainerView.alpha = 1
            self.idContainerView.alpha = 0
        } else {
            self.tagContainerView.alpha = 0
            self.idContainerView.alpha = 1
        }
    }
    
}

