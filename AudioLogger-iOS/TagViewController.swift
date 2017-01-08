//
//  TagViewController.swift
//  AudioLogger-iOS
//
//  Created by Bryan on 1/1/17.
//  Copyright © 2017 bcattle. All rights reserved.
//

import UIKit
import AVFoundation
import AudioToolbox
import EZAudioiOS
import JPSVolumeButtonHandler

let AudioImageCellIdentifier = "AudioImageCell"
let AudioPlotCellIdentifier = "AudioPlotCell"

typealias AudioImageCell = FullscreenCell<UIImageView>
typealias AudioPlotCell = FullscreenCell<EZAudioPlotGL>

class TagViewController: UIViewController {
    
    @IBOutlet weak var tableView:UITableView!
    
    var audioPlot:EZAudioPlotGL?
    var microphone:EZMicrophone?
    var recorder:EZRecorder?
    
    var prevRows:[UIImage] = [UIImage]()
    var bufferCount = 0     // The number of microphone buffers we have received
    var sampleCount = 0     // The number of samples we have received
    var sampleRate:Int? = nil
    var samplesPerUpdate:Int? = nil
    var buttonHandler:JPSVolumeButtonHandler?
    
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
        
        let plotColor:Float = 50 / 255.0
        
        // Set up the audio plot and microphone
        audioPlot = EZAudioPlotGL()
        audioPlot!.backgroundColor = UIColor.clear
        audioPlot!.color           = UIColor(colorLiteralRed: plotColor, green: plotColor, blue: plotColor, alpha: 1)
        audioPlot!.plotType        = .rolling
        audioPlot!.shouldFill      = true
        audioPlot!.shouldMirror    = true
        audioPlot!.gain = 10.0
        
        microphone = EZMicrophone(delegate: self)
        microphone!.startFetchingAudio()
        
        // Intercept the volume buttons
        buttonHandler = JPSVolumeButtonHandler(up: { [weak self] in
            self?.volumeButtonTapped()
        }, downBlock: { [weak self] in
            self?.volumeButtonTapped()
        })
        buttonHandler!.start(true)
    }
    
    func getSecs(numSamples: Int, sampleRate: Int) -> Float {
        return Float(numSamples) / Float(sampleRate)
    }

    func volumeButtonTapped() {
        if recorder == nil {
            startRecording()
        } else {
            stopRecording()
        }
    }
    
    func startRecording() {
        // The microphone is already running, to start recording we make a recorder
        // and it will get fed by the microphone on the next update
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MMM-d h:mm:ss a"
        let dateStr = formatter.string(from: Date())
        let outputFile = "\(dateStr).m4a"
        let documents = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]

        let outputURL = URL(fileURLWithPath: documents).appendingPathComponent(outputFile)
        recorder = EZRecorder(url: outputURL, clientFormat: microphone!.audioStreamBasicDescription(), fileType: .M4A)
        
//        // Set the encoder bitrate
//        var audioConverter = AudioConverterRef()
//        var propSize = UInt32(MemoryLayout<AudioConverterRef>.size)
//        
//        var status = ExtAudioFileGetProperty(recorder!.info.pointee.extAudioFileRef,
//                                             kExtAudioFileProperty_AudioConverter,
//                                             &propSize,
//                                             &audioConverter)
//        
//        var bitrate:UInt32
//        var brSize = UInt32(MemoryLayout<UInt32>.size)
//        AudioConverterGetProperty(audioConverter, kAudioConverterEncodeBitRate, &brSize, &bitrate)
////        AudioConverterSetProperty(audioConverter, kAudioConverterEncodeBitRate, &brSize, &bitrate)
        
        print("Starting to record to \(outputFile)")
    }
    
    func stopRecording() {
        recorder?.closeAudioFile()
        recorder = nil
        print("Finished recording")
    }
}

extension TagViewController: EZMicrophoneDelegate {
    func microphone(_ microphone: EZMicrophone!, hasAudioStreamBasicDescription
        audioStreamBasicDescription: AudioStreamBasicDescription)
    {
        // EZAudioUtilities.printASBD(audioStreamBasicDescription)
        DispatchQueue.main.async { [weak self] in
            self?.sampleRate = Int(round(audioStreamBasicDescription.mSampleRate))
        }
    }
    
//    func microphone(_ microphone: EZMicrophone!, changedPlayingState isPlaying: Bool) {
//        DispatchQueue.main.async { [weak self] in
//            if isPlaying {
//                
//            } else {
//                
//            }
//        }
//    }
    
    func microphone(_ microphone: EZMicrophone!,
                    hasAudioReceived buffer: UnsafeMutablePointer<UnsafeMutablePointer<Float>?>!,
                    withBufferSize bufferSize: UInt32,
                    withNumberOfChannels numberOfChannels: UInt32)
    {
        DispatchQueue.main.async { [weak self] in
            if let strongSelf = self {
                if let audioPlot = strongSelf.audioPlot {
                    audioPlot.updateBuffer(buffer[0], withBufferSize:bufferSize)
                    strongSelf.bufferCount += 1
                    strongSelf.sampleCount += Int(bufferSize)
                    strongSelf.samplesPerUpdate = Int(bufferSize)
                    // A full screen's width is `audioPlot.rollingHistoryLength()` buffers
                    if strongSelf.bufferCount % Int(audioPlot.rollingHistoryLength()) == 0 {
                        // Make a new row
                        strongSelf.prevRows.append(audioPlot.snapshot)
                        audioPlot.clear()
                        UIView.performWithoutAnimation {
                            strongSelf.tableView.insertRows(at: [IndexPath(row:strongSelf.prevRows.count - 1, section:0)], with: .none)
                        }
                        strongSelf.tableView.scrollToRow(at: IndexPath(row:strongSelf.prevRows.count, section:0), at: .bottom, animated: true)
                    }
                }
            }
        }
    }
    
    func microphone(_ microphone: EZMicrophone!,
                    hasBufferList bufferList: UnsafeMutablePointer<AudioBufferList>!,
                    withBufferSize bufferSize: UInt32,
                    withNumberOfChannels numberOfChannels: UInt32)
    {
        DispatchQueue.main.async { [weak self] in
            // Can be fed to EZRecorder or EZOutput
            if let recorder = self?.recorder {
                recorder.appendData(from:bufferList, withBufferSize:bufferSize)
            }
        }
    }
}

extension TagViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return prevRows.count + 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row == self.tableView(tableView, numberOfRowsInSection: indexPath.section) - 1 {
            // Last row, the audio plot cell
            let cell = tableView.dequeueReusableCell(withIdentifier: AudioPlotCellIdentifier, for: indexPath) as! AudioPlotCell
            cell.fullscreenView = audioPlot
            cell.backgroundColor = UIColor.clear
            return cell
        }
        else {
            // An audio image cell
            let cell = tableView.dequeueReusableCell(withIdentifier: AudioImageCellIdentifier, for: indexPath) as! AudioImageCell
            cell.fullscreenView?.image = prevRows[indexPath.row]
            cell.backgroundColor = UIColor.clear
            return cell
        }
    }
}
