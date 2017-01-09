//
//  FileCell.swift
//  AudioLogger-iOS
//
//  Created by Bryan on 1/9/17.
//  Copyright © 2017 bcattle. All rights reserved.
//

import UIKit

class FileCell: UITableViewCell {
    @IBOutlet weak var label:UILabel!
    @IBOutlet weak var sizeLabel:UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code

    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
        if selected {
            backgroundColor = UIColor.darkGray
        } else {
            backgroundColor = UIColor.clear
        }
    }

}
