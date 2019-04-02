//
//  FTFeedDetailViewController.swift
//  FeedTrue
//
//  Created by Quoc Le on 11/26/18.
//  Copyright © 2018 toanle. All rights reserved.
//

import UIKit
import STPopup

enum DetailMenuDisplayType {
    case reacted
    case comment
}

class FTFeedDetailViewController: UIViewController {

    private var datas: [String] = ["Reacted (0)", "Comments (0)"]

    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var reactTableView: UITableView!
    var feedInfo: FTFeedInfo!
    var coreService: FTCoreService!
    var dataSource = [[BECellDataSource]]()
    var commentDataSource = [BECellDataSource]()
    var reactedDataSource = [BECellDataSource]()
    var selectedMenuType: DetailMenuDisplayType = .reacted
    var photos: [Photo]?
    var skPhotos: [SKPhoto]?
    var bottomReactionDataSource = [FTBottomReactionViewModel]()
    var nextCommentURL: String?
    var nextReactedURL: String?
    var segmentSelectedIndex = 0
    
    var commentPageInfo: PageInfo?
    var reactionsPageInfo: PageInfo?
    
    lazy var navTitleView: UIView = {
        let navView = UIView()
        
        // Create the label
        let label = UILabel()
        label.text = getUserName()
        label.sizeToFit()
        label.center = navView.center
        label.textAlignment = .center
        label.textColor = .white
        
        // Create the image view
        let avatarImageView = UIImageView()
        if let urlString = feedInfo.user?.avatar {
            if let url = URL(string: urlString) {
                avatarImageView.loadImage(fromURL: url, defaultImage: UIImage.userImage())
            } else {
                avatarImageView.image = UIImage.userImage()
            }
        } else {
            avatarImageView.image = UIImage.userImage()
        }
        // To maintain the image's aspect ratio:
        let imageAspect = avatarImageView.image!.size.width / avatarImageView.image!.size.height
        // Setting the image frame so that it's immediately before the text:
        avatarImageView.frame = CGRect(x: label.frame.origin.x - 40, y: label.frame.origin.y - 8, width: 32, height: 32)
        avatarImageView.contentMode = .scaleAspectFit
        avatarImageView.round()
        
        // Add both the label and image view to the navView
        navView.addSubview(label)
        navView.addSubview(avatarImageView)
        return navView
    }()
    
    lazy var swipeMenuView: SwipeMenuView = {
        let swipeMenuView = SwipeMenuView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
        swipeMenuView.delegate                        = self
        swipeMenuView.dataSource                      = self
        var options: SwipeMenuViewOptions             = .init()
        options.tabView.style                         = .segmented
        options.tabView.additionView.backgroundColor  = .white
        options.tabView.itemView.textColor            = .black
        options.tabView.itemView.font = UIFont.swipeMenuFont(ofSize: 17)
        options.tabView.needsAdjustItemViewWidth = false
        return swipeMenuView
    }()
    
    lazy var segmentControl: SegmentedControl = {
       let segment = SegmentedControl(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 64))
        segment.setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.gray, NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 20)], for: .normal)
        segment.setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.black, NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 20)], for: .selected)
        segment.tintColor = .clear
        segment.insertSegment(withTitle: "Reacted (\(feedInfo.reactions?.count ?? 0))", at: 0, animated: false)
        segment.insertSegment(withTitle: "Comments (\(feedInfo.comment?.count ?? 0))", at: 1, animated: false)
        segment.selectedSegmentIndex = segmentSelectedIndex
        segment.addTarget(self, action: #selector(didChange(segmentControl:)), for: .valueChanged)
        return segment
    }()
    
    @IBAction func didChange(segmentControl: SegmentedControl) {
        if segmentControl.selectedSegmentIndex == 0 {
            selectedMenuType = .reacted
        } else if segmentControl.selectedSegmentIndex == 1 {
            selectedMenuType = .comment
        }
        
        if self.dataSource.count > 1 {
            self.dataSource[1] = selectedDataSource()
        }
        
        self.tableView.reloadData()
    }
    
    func selectedDataSource() -> [BECellDataSource] {
        switch selectedMenuType {
        case .comment:
            return commentDataSource
        case .reacted:
            return reactedDataSource
        }
    }
    
    init(feedInfo info: FTFeedInfo, coreService service: FTCoreService) {
        self.feedInfo = info
        self.coreService = service
        super.init(nibName: "FTFeedDetailViewController", bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        let backBarBtn = UIBarButtonItem(image: UIImage(named: "back"), style: .plain, target: self, action: #selector(back(_:)))
        backBarBtn.tintColor = UIColor.navigationTitleTextColor()
        self.navigationItem.leftBarButtonItem = backBarBtn
        
        navigationItem.titleView = navTitleView
        
        let rightBarBtn = UIBarButtonItem(image: UIImage(named: "more_btn"), style: .plain, target: self, action: #selector(more(_:)))
        rightBarBtn.tintColor = .white
        navigationItem.rightBarButtonItem = rightBarBtn
        
        // table view
        dataSource = []
        FTDetailFeedContentViewModel.register(tableView: tableView)
        FTDetailPhotosViewModel.register(tableView: tableView)
        FTCommentViewModel.register(tableView: tableView)
        FTReactionViewModel.register(tableView: tableView)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = UIView()
        tableView.separatorInset = .zero
        tableView.layer.cornerRadius = 8
        tableView.clipsToBounds = true
        tableView.separatorStyle = .none
        generateDataSource()
        
        bottomReactionDataSource = []
        FTBottomReactionViewModel.register(tableView: reactTableView)
        reactTableView.delegate = self
        reactTableView.dataSource = self
        reactTableView.tableFooterView = UIView()
        reactTableView.separatorInset = .zero
        reactTableView.layer.cornerRadius = 8
        reactTableView.clipsToBounds = true
        reactTableView.separatorStyle = .none
        generateReactionDatasource()
        loadFeedDetail()
        loadMoreComments()
    }
    
    fileprivate func generateDataSource() {
        let contentVM = FTDetailFeedContentViewModel(content: feedInfo.text ?? "")
        let photoVM = FTDetailPhotosViewModel(photos: photos ?? [])
        dataSource.append([contentVM, photoVM])
        
        // reactions | comments
        generateCommentDataSource()
        generateReactionDataSource()
        
        dataSource.append(selectedDataSource())
    }
    
    fileprivate func loadFeedDetail() {
        guard let uid = feedInfo.uid else { return }
        WebService.share.getFeedDetail(uid: uid) { (success, feedInfoResponse) in
            if success {
                self.feedInfo = feedInfoResponse
                self.nextCommentURL = feedInfoResponse?.comment?.next
                self.nextReactedURL = feedInfoResponse?.reactions?.next
                // update comments/reactions
                self.generateCommentDataSource()
                self.generateReactionDataSource()
                
                if self.dataSource.count > 1 {
                    self.dataSource[1] = self.selectedDataSource()
                    DispatchQueue.main.async {
                        self.tableView.reloadSections(IndexSet(integer: 1), with: .none)
                        self.tableView.addBotomActivityView {
                            self.loadMore()
                        }
                    }
                }
            }
        }
    }
    
    private func loadMore() {
        switch selectedMenuType {
        case .comment:
            // load more comment
            guard let url = nextCommentURL else {
                self.tableView.endBottomActivity()
                return
            }
            WebService.share.getMoreCommentsByNextURL(next: url) { (success, commentResponse) in
                
                DispatchQueue.main.async {
                    self.tableView.endBottomActivity()
                }
                
                if success {
                    self.nextCommentURL = commentResponse?.next
                    guard let comments = commentResponse?.comments else { return }
                    for comment in comments {
                        let commentVM = FTCommentViewModel(comment: comment, type: .text)
                        self.commentDataSource.append(commentVM)
                    }
                    
                    DispatchQueue.main.async {
                        if self.dataSource.count > 1 {
                            self.dataSource[1] = self.selectedDataSource()
                        }
                        self.tableView.reloadSections(IndexSet(integer: 1), with: .none)
                    }
                } else {
                    print("\(#function) load more comment failure")
                }
            }
        case .reacted:
            // load more reacted
            guard let reactionsURL = self.nextReactedURL else {
                self.tableView.endBottomActivity()
                return
            }
            
            WebService.share.getMoreReactionsByNextURL(next: reactionsURL) { (success, reactionResponse) in
                DispatchQueue.main.async {
                    self.tableView.endBottomActivity()
                }
                
                if success {
                    print(reactionResponse.debugDescription)
                    self.nextReactedURL = reactionResponse?.next
                    guard let reactions = reactionResponse?.data else { return }
                    for reaction in reactions {
                        let reactionVM = FTReactionViewModel(reaction: reaction)
                        self.reactedDataSource.append(reactionVM)
                    }
                    
                    DispatchQueue.main.async {
                        if self.dataSource.count > 1 {
                            self.dataSource[1] = self.selectedDataSource()
                        }
                        self.tableView.reloadSections(IndexSet(integer: 1), with: .none)
                    }
                    
                } else {
                    print("\(#function) load more reactions failure")
                }
            }
        }
    }
    
    fileprivate func generateCommentDataSource() {
        guard let comments = feedInfo.comment?.comments else { return }
        var commentDS: [BECellDataSource] = []
        for comment in comments {
            let commentVM = FTCommentViewModel(comment: comment, type: .text)
            commentDS.append(commentVM)
        }
        datas[1] = "Comments (\(comments.count))"
        commentDataSource = commentDS
    }
    
    fileprivate func generateReactionDataSource() {
        guard let reactions = feedInfo.reactions?.data else { return }
        var reactionDS: [BECellDataSource] = []
        for reaction in reactions {
            let reactionVM = FTReactionViewModel(reaction: reaction)
            reactionDS.append(reactionVM)
        }
        
        datas[0] = "Reacted (\(feedInfo.reactions?.count ?? 0))"
        reactedDataSource = reactionDS
    }
    
    fileprivate func generateReactionDatasource() {
        let reactionVM = FTBottomReactionViewModel(reactionType: .love)
        reactionVM.feedInfo = feedInfo
        bottomReactionDataSource.append(reactionVM)
    }
    
    @objc func back(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }
    
    fileprivate func getUserName() -> String? {
        guard let username = feedInfo.user?.last_name else { return nil }
        return username
    }
    
    @objc func more(_ sender: Any) {
        
        /*
         Case 1: If feed.editable = false (Case feed owner is not request user), user can be get into these actions:
         Go to feed: Change screen into FEED DETAIL
         Share: Open Share Feed Modal
         See less content: Temporarily open modal: "You wont see this content anymore" and remove this feed out of feed list.
         Report inapproriate: Temporarily open modal: "Successfully reported" and remove this feed out of feed list.
         */
        let gotoFeedAction = UIAlertAction(title: NSLocalizedString("Go to feed", comment: ""), style: .default) { (action) in
            //self.delegate?.feeddCellGotoFeed(cell: self)
        }
        
        let shareAction = UIAlertAction(title: NSLocalizedString("Share", comment: ""), style: .default) { (action) in
            //self.delegate?.feeddCellShare(cell: self)
        }
        
        let seeLessContentAction = UIAlertAction(title: NSLocalizedString("See less content", comment: ""), style: .default) { (action) in
            //self.delegate?.feeddCellSeeLessContent(cell: self)
        }
        
        let reportInapproriate = UIAlertAction(title: NSLocalizedString("Report inapproriate", comment: ""), style: .default) { (action) in
            //self.delegate?.feeddCellReportInapproriate(cell: self)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (action) in
            // user cancel
        }
        
        var actions:[UIAlertAction] = []
        if feedInfo.editable == true {
            /*
             Edit: Open modal Edit
             Permanently Delete: (with text-color Red): DELETE /f/${feedID}/delete/ and remove this feed out of feed list
             */
            let editAction = UIAlertAction(title: NSLocalizedString("Edit", comment: ""), style: .default) { (action) in
                //self.delegate?.feeddCellEdit(cell: self)
            }
            
            let permanentlyDeleteAction = UIAlertAction(title: NSLocalizedString("Permanently Delete", comment: ""), style: .destructive) { (action) in
                //self.delegate?.feeddCellPermanentlyDelete(cell: self)
                
            }
            actions = [gotoFeedAction, shareAction, seeLessContentAction, reportInapproriate, editAction, permanentlyDeleteAction, cancelAction]
        } else {
            actions = [gotoFeedAction, shareAction, seeLessContentAction, reportInapproriate, cancelAction]
        }
        FTAlertViewManager.defaultManager.showActions(nil, message: nil, actions: actions, view: self)
    }

    
    private func loadMoreComments() {
        //guard let contentType = feedInfo.feedcontent?.type else { return }
        //guard let objectID = feedInfo.id else { return }
        WebService.share.getMoreComments(limit: 10, offset: 0, contentType: 23, objectID: 174) { (success, response) in
            if success {
                print(response.debugDescription)
            }
        }
    }
    
    private func loadMoreReactions() {
        
    }
}

extension FTFeedDetailViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        if tableView == reactTableView {
            return 1
        }
        return dataSource.count
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == reactTableView {
            return bottomReactionDataSource.count
        }
        return dataSource[section].count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView == reactTableView {
            let content = bottomReactionDataSource[indexPath.row]
            let cell = tableView.dequeueReusableCell(withIdentifier: content.cellIdentifier())!
            
            if let renderCell = cell as? BECellRender {
                renderCell.renderCell(data: content)
            }
            
            if let reactionCell = cell as? FTBottomReactionTableViewCell {
                reactionCell.delegate = self
            }
            return cell
        }
        
        let content = dataSource[indexPath.section][indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: content.cellIdentifier())!
        
        if let renderCell = cell as? BECellRender {
            renderCell.renderCell(data: content)
        }
        
        return cell
    }
    
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if tableView == reactTableView {
            let content = bottomReactionDataSource[indexPath.row]
            return content.cellHeight()
        }
        let content = dataSource[indexPath.section][indexPath.row]
        return content.cellHeight()
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if tableView == reactTableView {
            return nil
        }
        if section == 0 { return nil }
        return segmentControl
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if tableView == reactTableView {
            return 0
        }
        if section == 0 { return 0 }
        return segmentControl.bounds.height
    }
    
}

extension FTFeedDetailViewController: SwipeMenuViewDelegate, SwipeMenuViewDataSource {
    func swipeMenuView(_ swipeMenuView: SwipeMenuView, viewControllerForPageAt index: Int) -> UIViewController {
        return UIViewController()
    }
    
    func swipeMenuView(_ swipeMenuView: SwipeMenuView, titleForPageAt index: Int) -> String {
        return datas[index]
    }
    
    func numberOfPages(in swipeMenuView: SwipeMenuView) -> Int {
        return datas.count
    }
    
    func swipeMenuView(_ swipeMenuView: SwipeMenuView, didChangeIndexFrom fromIndex: Int, to toIndex: Int) {
        if toIndex == 0 {
            selectedMenuType = .reacted
        } else if toIndex == 1 {
            selectedMenuType = .comment
        }
        
        if self.dataSource.count > 1 {
            self.dataSource[1] = selectedDataSource()
        }
        
        self.tableView.reloadData()
    }
    
}

extension FTFeedDetailViewController: BottomReactionCellDelegate {
    func reactionDidRemove(cell: FTBottomReactionTableViewCell) {
        // TODO: remove reaction
        guard let ct_id = feedInfo.id else { return }
        guard let ct_name = feedInfo.ct_name else { return }
        coreService.webService?.removeReact(ct_name: ct_name, ct_id: ct_id, completion: { (success, msg) in
            if success {
                NSLog("Remove react successful")
            } else {
                NSLog("Remove react failed")
                DispatchQueue.main.async {
                    guard let indexPath = self.reactTableView.indexPath(for: cell) else { return }
                    self.reactTableView.reloadRows(at: [indexPath], with: .automatic)
                }
            }
        })
    }
    
    func reactionDidChange(cell: FTBottomReactionTableViewCell) {
        // TODO: reaction change
        guard let ct_id = feedInfo.id else { return }
        guard let ct_name = feedInfo.ct_name else { return }
        guard let react_type = cell.contentData?.ftReactionType.rawValue else { return }
        coreService.webService?.react(ct_name: ct_name, ct_id: ct_id, react_type: react_type, completion: { (success, type) in
            if success {
                NSLog("did react successful \(type ?? "")")
            } else {
                NSLog("did react failed \(react_type)")
                DispatchQueue.main.async {
                    guard let indexPath = self.reactTableView.indexPath(for: cell) else { return }
                    self.reactTableView.reloadRows(at: [indexPath], with: .automatic)
                }
            }
        })
    }
    
    func commentDidTouchUpAction(cell: FTBottomReactionTableViewCell) {
        // TODO: open comment view controller
        var comments: [FTCommentViewModel] = []
        if let items = feedInfo.comment?.comments {
            for item in items {
                let cmv = FTCommentViewModel(comment: item, type: .text)
                comments.append(cmv)
            }
        }
        
        let commentVC = CommentController(c: coreService, contentID: feedInfo.id, ctName: feedInfo.ct_name)
        commentVC.contentSizeInPopup = CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height*0.75)
        let popupController = STPopupController(rootViewController: commentVC)
        popupController.style = .bottomSheet
        popupController.present(in: self)
    }
    
    func reationDidUnSave(cell: FTBottomReactionTableViewCell) {
        guard let ct_id = feedInfo.id else { return }
        guard let ct_name = feedInfo.ct_name else { return }
        coreService.webService?.removeSaveFeed(ct_name: ct_name, ct_id: ct_id, completion: { (success, message) in
            if success {
                NSLog("Remove saved Feed successful ct_name: \(ct_name) ct_id: \(ct_id)")
            } else {
                NSLog("Remove saved Feed failed ct_name: \(ct_name) ct_id: \(ct_id)")
                DispatchQueue.main.async {
                    guard let indexPath = self.reactTableView.indexPath(for: cell) else { return }
                    cell.contentData?.feedInfo?.saved = true
                    self.reactTableView.reloadRows(at: [indexPath], with: .automatic)
                }
            }
        })
    }
    
    func reactionDidSave(cell: FTBottomReactionTableViewCell) {
        guard let ct_id = feedInfo.id else { return }
        guard let ct_name = feedInfo.ct_name else { return }
        coreService.webService?.saveFeed(ct_name: ct_name, ct_id: ct_id, completion: { (success, message) in
            if success {
                NSLog("Save Feed successful ct_name: \(ct_name) ct_id: \(ct_id)")
            } else {
                NSLog("Save Feed failed ct_name: \(ct_name) ct_id: \(ct_id)")
                DispatchQueue.main.async {
                    guard let indexPath = self.reactTableView.indexPath(for: cell) else { return }
                    cell.contentData?.feedInfo?.saved = false
                    self.reactTableView.reloadRows(at: [indexPath], with: .automatic)
                }
            }
        })
    }
}
