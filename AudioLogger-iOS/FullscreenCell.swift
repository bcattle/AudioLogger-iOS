//
//  FullscreenCell.swift
//  AudioLogger-iOS
//
//  Created by Bryan on 1/6/17.
//  Copyright © 2017 bcattle. All rights reserved.
//

import UIKit
import Cartography

class FullscreenCell<T:UIView>: UITableViewCell {
    var fullscreenView: T? {
        didSet {
            if let oldView = oldValue {
                oldView.removeFromSuperview()
            }
            if let newView = fullscreenView {
                addSubview(newView)
                constrain(newView) { view in
                    view.left == view.superview!.left
                    view.right == view.superview!.right
                    view.top == view.superview!.top
                    view.bottom == view.superview!.bottom
                }
            }
        }
    }
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    private func setup() {
        fullscreenView = T.init()
    }
}
