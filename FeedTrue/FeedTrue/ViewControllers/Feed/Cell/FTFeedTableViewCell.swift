//
//  FTFeedTableViewCell.swift
//  FeedTrue
//
//  Created by Quoc Le on 9/13/18.
//  Copyright © 2018 toanle. All rights reserved.
//

import UIKit
import SwiftMoment

@objc protocol FTFeedCellDelegate {
    func feeddCellGotoFeed(cell: FTFeedTableViewCell)
    func feeddCellShare(cell: FTFeedTableViewCell)
    func feeddCellSeeLessContent(cell: FTFeedTableViewCell)
    func feeddCellReportInapproriate(cell: FTFeedTableViewCell)
    func feeddCellEdit(cell: FTFeedTableViewCell)
    @objc func feeddCellPermanentlyDelete(cell: FTFeedTableViewCell)
}

class FTFeedTableViewCell: UITableViewCell, BECellRenderImpl {
    typealias CellData = FTFeedViewModel
    weak var delegate: FTFeedCellDelegate?
    var feed: FTFeedInfo!
    
    @IBOutlet weak var userAvatarImageview: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var contentLabel: UILabel!
    @IBOutlet weak var loveLabel: UILabel!
    @IBOutlet weak var commentLabel: UILabel!
    @IBOutlet weak var shareLabel: UILabel!
    @IBOutlet weak var saveLabel: UILabel!
    @IBOutlet weak var commentTextField: UITextField!
    @IBOutlet weak var commentView: UIView!
    @IBOutlet weak var moreBtn: UIButton!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var collectionLayoutConstraint: NSLayoutConstraint!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        commentTextField.returnKeyType = .done
        commentTextField.delegate = self
        self.selectionStyle = .none
        
        // setup lables
        setUpLabels()
        userAvatarImageview.round()
    }
    
    func renderCell(data: FTFeedViewModel) {
        feed = data.feed
        if let urlString = feed.user?.avatar {
            if let url = URL(string: urlString) {
                self.userAvatarImageview.loadImage(fromURL: url)
            }
        } else {
            self.userAvatarImageview.image = UIImage(named: "1000x1000")
        }
        self.nameLabel.text = feed.user?.full_name
        if let dateString = feed.date {
            self.dateLabel.text = moment(dateString)?.fromNow()
        } else {
            self.dateLabel.text = nil
        }
        self.contentLabel.text = feed.text?.htmlToString
        
        let photoController = PhotosController(dataSourceType: .remote)
        photoController.collectionView?.isScrollEnabled = false
//        self.addChildViewController(photoController)
//        self.collectionView.addSubview(photoController.view)
//        self.collectionView.isScrollEnabled = false
//        photoController.didMove(toParentViewController: self)
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    private func setUpLabels() {
        let loveAttrString = FTHelpers.attributeString(imageNamed: "love", str: NSLocalizedString("Love", comment: ""))
        loveLabel.attributedText = loveAttrString
        
        let commentAttrString = FTHelpers.attributeString(imageNamed: "comment", str: NSLocalizedString("Comment", comment: ""))
        commentLabel.attributedText = commentAttrString
        
        let shareAttrString = FTHelpers.attributeString(imageNamed: "share", str: NSLocalizedString("Share", comment: ""))
        shareLabel.attributedText = shareAttrString
        
        let saveAttrString = FTHelpers.attributeString(imageNamed: "save", str: NSLocalizedString("Save", comment: ""))
        saveLabel.attributedText = saveAttrString
    }
    
    @IBAction func moreBtnPressed(_ sender: Any) {
        
        /*
         Case 1: If feed.editable = false (Case feed owner is not request user), user can be get into these actions:
         Go to feed: Change screen into FEED DETAIL
         Share: Open Share Feed Modal
         See less content: Temporarily open modal: "You wont see this content anymore" and remove this feed out of feed list.
         Report inapproriate: Temporarily open modal: "Successfully reported" and remove this feed out of feed list.
         */
        let gotoFeedAction = UIAlertAction(title: NSLocalizedString("Go to feed", comment: ""), style: .default) { (action) in
            self.delegate?.feeddCellGotoFeed(cell: self)
        }
        
        let shareAction = UIAlertAction(title: NSLocalizedString("Share", comment: ""), style: .default) { (action) in
            self.delegate?.feeddCellShare(cell: self)
        }
        
        let seeLessContentAction = UIAlertAction(title: NSLocalizedString("See less content", comment: ""), style: .default) { (action) in
            self.delegate?.feeddCellSeeLessContent(cell: self)
        }
        
        let reportInapproriate = UIAlertAction(title: NSLocalizedString("Report inapproriate", comment: ""), style: .default) { (action) in
            self.delegate?.feeddCellReportInapproriate(cell: self)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (action) in
            // user cancel
        }
        
        var actions:[UIAlertAction] = []
        if feed.editable == true {
            /*
             Edit: Open modal Edit
             Permanently Delete: (with text-color Red): DELETE /f/${feedID}/delete/ and remove this feed out of feed list
             */
            let editAction = UIAlertAction(title: NSLocalizedString("Edit", comment: ""), style: .default) { (action) in
                self.delegate?.feeddCellEdit(cell: self)
            }
            
            let permanentlyDeleteAction = UIAlertAction(title: NSLocalizedString("Permanently Delete", comment: ""), style: .destructive) { (action) in
                self.delegate?.feeddCellPermanentlyDelete(cell: self)
                
            }
            actions = [gotoFeedAction, shareAction, seeLessContentAction, reportInapproriate, editAction, permanentlyDeleteAction, cancelAction]
        } else {
            actions = [gotoFeedAction, shareAction, seeLessContentAction, reportInapproriate, cancelAction]
        }
        FTAlertViewManager.defaultManager.showActions(nil, message: nil, actions: actions, view: self)
    }
    
    
}

extension FTFeedTableViewCell: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.commentTextField.endEditing(true)
        return true
    }
}
