//
//  UIImageView+Url.swift
//  Utility
//
//  Created by Nguyen Tuan on 7/5/17.
//  Copyright © 2017 Nguyen Tuan. All rights reserved.
//

import UIKit

extension UIImageView {
    public func loadImage(fromURL: URL?, defaultImage: UIImage? = nil) {
        if let url = fromURL?.absoluteString, url.contains(".gif") {
            self.setGifFromURL(fromURL)
        } else {
            FileProviderService.service.imageView(self, loadImage: fromURL, defaultImage: defaultImage)
            SwiftyGifManager.defaultManager.deleteImageView(self)
        }
    }
    
    func round() {
        self.layer.cornerRadius = self.frame.size.width/2
        self.clipsToBounds = true
    }
}
