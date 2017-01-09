//
//  DualFullscreenCell.swift
//  AudioLogger-iOS
//
//  Created by Bryan on 1/8/17.
//  Copyright © 2017 bcattle. All rights reserved.
//

import UIKit
import Cartography

class DualFullscreenCell<T:UIView, U:UIView>: UITableViewCell {
    var constraintGroup = ConstraintGroup()
    var leftView: T? {
        didSet {
            if let oldView = oldValue {
                oldView.removeFromSuperview()
            }
            if let newView = leftView {
                addSubview(newView)
            }
        }
    }
    var rightView: U? {
        didSet {
            if let oldView = oldValue {
                oldView.removeFromSuperview()
            }
            if let newView = rightView {
                addSubview(newView)
            }
        }
    }
    
    var leftViewWidth: CGFloat? {
        didSet {
            if let newWidth = leftViewWidth {
                constrain(leftView!, rightView!, replace:constraintGroup) { view, view2 in
                    view.left == view.superview!.left
                    view.right == view2.left
                    view.top == view.superview!.top
                    view.bottom == view.superview!.bottom
                    view.width == newWidth
                    view2.top == view.superview!.top
                    view2.bottom == view.superview!.bottom
                    view2.right == view2.superview!.right
                }
            }
        }
    }
}
