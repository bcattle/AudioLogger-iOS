//
//  TagViewController.swift
//  AudioLogger-iOS
//
//  Created by Bryan on 1/1/17.
//  Copyright © 2017 bcattle. All rights reserved.
//

import UIKit
import AVFoundation
import EZAudio

let AudioImageCellIdentifier = "AudioImageCell"
let AudioPlotCellIdentifier = "AudioPlotCell"

typealias AudioImageCell = FullscreenCell<UIImageView>
typealias AudioPlotCell = FullscreenCell<EZAudioPlotGL>

class TagViewController: UIViewController {
    @IBOutlet weak var tableView:UITableView!
    var audioPlot:EZAudioPlotGL?
    var microphone:EZMicrophone?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up the table view
        let rowHeight = UIScreen.main.bounds.height / 6.0
        tableView.rowHeight = rowHeight
        tableView.register(AudioImageCell.self, forCellReuseIdentifier: AudioImageCellIdentifier)
        tableView.register(AudioPlotCell.self, forCellReuseIdentifier: AudioPlotCellIdentifier)
        
        // Set up the audio session
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(AVAudioSessionCategoryRecord)
            try session.setActive(true)
        } catch let error {
            print("Error setting up audio session: \(error)")
            return
        }
        
        let plotColor:Float = 40 / 255.0
        
        // Set up the audio plot and microphone
        audioPlot = EZAudioPlotGL()
        audioPlot!.backgroundColor = UIColor.clear
        audioPlot!.color           = UIColor(colorLiteralRed: plotColor, green: plotColor, blue: plotColor, alpha: 1)
        audioPlot!.plotType        = .rolling
        audioPlot!.shouldFill      = true
        audioPlot!.shouldMirror    = true
        audioPlot!.gain = 8.0
        
        microphone = EZMicrophone(delegate: self)
        microphone!.startFetchingAudio()
    }
}

extension TagViewController: EZMicrophoneDelegate {
    func microphone(_ microphone: EZMicrophone!, hasAudioStreamBasicDescription
        audioStreamBasicDescription: AudioStreamBasicDescription)
    {
        EZAudioUtilities.printASBD(audioStreamBasicDescription)
    }
    
    func microphone(_ microphone: EZMicrophone!,
                    hasAudioReceived buffer: UnsafeMutablePointer<UnsafeMutablePointer<Float>?>!,
                    withBufferSize bufferSize: UInt32,
                    withNumberOfChannels numberOfChannels: UInt32)
    {
        if let audioPlot = audioPlot {
            DispatchQueue.main.async {
                audioPlot.updateBuffer(buffer[0], withBufferSize:bufferSize)
            }
        }
    }
    
    func microphone(_ microphone: EZMicrophone!,
                    hasBufferList bufferList: UnsafeMutablePointer<AudioBufferList>!,
                    withBufferSize bufferSize: UInt32,
                    withNumberOfChannels numberOfChannels: UInt32)
    {
        // Can be fed to EZRecorder or EZOutput
    }
}

extension TagViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
//        if indexPath.row == self.tableView(tableView, numberOfRowsInSection: indexPath.section) - 1 {
            // Last row, the audio plot cell
            let cell = tableView.dequeueReusableCell(withIdentifier: AudioPlotCellIdentifier, for: indexPath) as! AudioPlotCell
            cell.fullscreenView = audioPlot
            cell.backgroundColor = UIColor.clear
            return cell
//        }
//        else {
            // An audio image cell
            // let cell = tableView.dequeueReusableCell(withIdentifier: AudioImageCellIdentifier, for: indexPath) as! AudioPlotCell
            // cell.fullscreenView =
//        }
    }
}
