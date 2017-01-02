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
    }

    @IBAction func segmentTapped(sender: UISegmentedControl) {
//        let duration = 0.25
        if sender.selectedSegmentIndex == 0 {
//            UIView.animate(withDuration: duration, animations: {
                self.tagContainerView.alpha = 1
                self.idContainerView.alpha = 0
//            })
        } else {
//            UIView.animate(withDuration: duration, animations: {
                self.tagContainerView.alpha = 0
                self.idContainerView.alpha = 1
//            })
        }
    }

}

