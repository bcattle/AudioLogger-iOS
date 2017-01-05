//
//  MainViewController.swift
//  AudioLogger-iOS
//
//  Created by Bryan on 1/1/17.
//  Copyright © 2017 bcattle. All rights reserved.
//

import UIKit

class MainViewController: UIViewController {
    @IBOutlet weak var tagContainerView:UIView!
    @IBOutlet weak var idContainerView:UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        var fileUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        fileUrl.appendPathComponent("test.opus")
        let encoder = ALOpusEncoder(filename: fileUrl.path)
        encoder?.close()
        print("done")
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

