//
//  SectionTableViewCell.swift
//  imageTransfer
//
//  Created by Aleksander Nowakowski on 12/10/2017.
//  Copyright © 2017 Nordic Semiconductor ASA. All rights reserved.
//

import UIKit

class SectionTableViewCell: UITableViewCell {

    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var label: UILabel!
    
    func setEnabled(enabled: Bool) {
        if enabled {
            label.text = "SCANNING FOR CAMERA DEVICES..."
            activityIndicator.isHidden = false
            activityIndicator.startAnimating()
        } else {
            label.text = "DEVICES"
            activityIndicator.isHidden = true
            activityIndicator.stopAnimating()
        }
    }
}
