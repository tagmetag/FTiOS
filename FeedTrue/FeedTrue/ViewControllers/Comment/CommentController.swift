//
//  CommentController.swift
//  FeedTrue
//
//  Created by Quoc Le on 10/5/18.
//  Copyright © 2018 toanle. All rights reserved.
//

import UIKit

class CommentController: UITableViewController {
    enum CommentDataType {
        case comment
        case reply
    }
    
    var type: CommentDataType = .comment
    var feed: FTFeedInfo!
    var coreService: FTCoreService!
    var datasource: [[FTCommentViewModel]] = []
    var replyComment: FTCommentViewModel?
    var nextURLString: String?
    
    init(c: FTCoreService, f: FTFeedInfo, comments: [FTCommentViewModel]) {
        feed = f
        coreService = c
        super.init(nibName: "CommentController", bundle: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        FTCommentViewModel.register(tableView: self.tableView)
        self.tableView.separatorStyle = .none
        self.loadComment()
    }
    
    func loadComment() {
        guard let token = coreService.registrationService?.authenticationProfile?.accessToken else { return }
        guard let feedID = feed.id else { return }
        coreService.webService?.getComments(token: token, ct_id: feedID, completion: { [weak self] (success, response) in
            if success {
                // TODO: init datasource
                guard let results = response?.results else { return }
                self?.nextURLString = response?.next
                self?.datasource.removeAll()
                for item in results {
                    var comments:[ FTCommentViewModel] = []
                    comments.append(FTCommentViewModel(comment: item, type: .text))
                    if let replies = item.replies {
                        for rp in replies {
                            comments.append([FTCommentViewModel(comment: rp, type: .text)])
                        }
                    }
                    
                    self?.datasource.append(comments)
                }
                DispatchQueue.main.async {
                    self?.tableView.reloadData()
                    self?.tableView.addBotomActivityView {
                        self?.loadMore()
                    }
                }
            } else {
                // TODO:
            }
        })
    }
    
    func loadMore() {
        guard let nextURL = self.nextURLString, !nextURL.isEmpty else {
            self.tableView.removeBottomActivityView()
            return
        }
        guard let token = coreService.registrationService?.authenticationProfile?.accessToken else {
            return
        }
        
        coreService.webService?.getMoreComments(token: token, nextString: nextURL, completion: { [weak self] (success, response) in
            if success {
                NSLog("Load more comment successful \(response?.next ?? "")")
                self?.nextURLString = response?.next
                DispatchQueue.main.async {
                    if let results = response?.results {
                        if results.count > 0 {
                            self?.tableView.endBottomActivity()
                            for item in results {
                                var comments:[ FTCommentViewModel] = []
                                comments.append(FTCommentViewModel(comment: item, type: .text))
                                if let replies = item.replies {
                                    for rp in replies {
                                        comments.append([FTCommentViewModel(comment: rp, type: .text)])
                                    }
                                }
                                
                                self?.datasource.append(comments)
                            }
                            self?.tableView.reloadData()
                        } else {
                            self?.tableView.removeBottomActivityView()
                        }
                    }
                    
                    
                }
            } else {
                DispatchQueue.main.async {
                    self?.tableView.removeBottomActivityView()
                }
            }
        })
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    lazy var messageInputView: ChatAccessoryView! = {
        let footerView = ChatAccessoryView.getView(target: self, actionName: "SEND", action: #selector(sendMessage))
        return footerView
    }()
    
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    override var inputAccessoryView: UIView? {
        return self.messageInputView
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.becomeFirstResponder()
    }
    
    @objc func sendMessage() {
        if let text = self.messageInputView.textView.text {
            let messageText =  text.trimmingCharacters(in: .whitespacesAndNewlines)
            // do something with message view
            self.messageInputView.textView.text = ""
            self.messageInputView.textViewDidChange(messageInputView.textView)
            
            guard let ct_name = feed.ct_name else { return }
            guard let ct_id = feed.id else { return }
            guard let token = coreService.registrationService?.authenticationProfile?.accessToken else { return }
            let parentID = self.replyComment?.comment.id
            coreService.webService?.sendComment(token: token, ct_name: ct_name, ct_id: ct_id, comment: messageText, parentID: parentID, completion: { [weak self] (success, comment) in
                if success {
                    guard let c = comment else { return }
                    let cm = FTCommentViewModel(comment: c, type: .text)
                    self?.addComment(c: cm, parentID: parentID)
                    DispatchQueue.main.async {
                        self?.tableView.reloadData()
                        self?.type = .comment
                        self?.messageInputView.actionButton.setTitle("SEND", for: .normal)
                        self?.replyComment = nil
                    }
                    
                } else {
                    DispatchQueue.main.async {
                        self?.type = .comment
                        self?.messageInputView.actionButton.setTitle("SEND", for: .normal)
                        self?.replyComment = nil
                    }
                }
            })
        }
        // hide keyboard after send (just to show how accessory view behave when keyboard hides)
        self.messageInputView.textView.resignFirstResponder()
    }
    
    
    func addComment(c: FTCommentViewModel, parentID: Int?) {
        switch type {
        case .comment:
            datasource.append([c])
        case .reply:
            for i in 0..<datasource.count {
                guard let item_id = datasource[i].first?.comment.id else { continue }
                guard let parent_id = parentID else { continue }
                if item_id == parent_id {
                    datasource[i].append(c)
                }
            }
        }
    }
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return datasource.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return datasource[section].count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let content = datasource[indexPath.section][indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: content.cellIdentifier())!
        
        if let commentCell = cell as? BECellRender {
            commentCell.renderCell(data: content)
        }
        
        content.reply = { (comment) in
            self.messageInputView.actionButton.setTitle("REPLY", for: .normal)
            self.type = .reply
            self.replyComment = comment
        }
        
            if let c = cell as? FTCommentTextCell {
                if indexPath.row == 0 {
                    c.paddingLeftLayoutConstraint.constant = 8
                    c.replyBtn.isHidden = false
                } else {
                    c.paddingLeftLayoutConstraint.constant = 32
                    c.replyBtn.isHidden = true
                }
            }
        
        content.more = { (contentCell) in
            let deleteAction = UIAlertAction(title: "Delete", style: .destructive, handler: { (action) in
                NSLog("delete at index: \(indexPath.row)")
                guard let content = contentCell else { return }
                guard let ct_id = content.comment.id else { return }
                guard let token = self.coreService.registrationService?.authenticationProfile?.accessToken else { return }
                self.coreService.webService?.deleteComment(token: token, ct_id: ct_id, completion: { [weak self] (success, msg) in
                    if success {
                        self?.datasource.remove(at: indexPath.row)
                        DispatchQueue.main.async {
                            self?.tableView.reloadData()
                        }
                    }
                })
            })
            
            let editAction = UIAlertAction(title: NSLocalizedString("Edit", comment: ""), style: .default, handler: { (action) in
                
            })
            
            let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .default, handler: { (action) in
                
            })
            
            FTAlertViewManager.defaultManager.showActions(nil, message: nil, actions: [deleteAction, editAction, cancelAction], view: self)
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let content = datasource[indexPath.section][indexPath.row]
        return content.cellHeight()
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        let content = datasource[indexPath.section][indexPath.row]
        if content.comment.editable == false {
            return false
        }
        
        return false
    }
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let deleteAction = UITableViewRowAction(style: .destructive, title: "Delete") { (action, indexPath) in
            NSLog("delete at index: \(indexPath.row)")
            let content = self.datasource[indexPath.section][indexPath.row]
            guard let ct_id = content.comment.id else { return }
            guard let token = self.coreService.registrationService?.authenticationProfile?.accessToken else { return }
            self.coreService.webService?.deleteComment(token: token, ct_id: ct_id, completion: { [weak self] (success, msg) in
                if success {
                    self?.datasource.remove(at: indexPath.row)
                    DispatchQueue.main.async {
                        self?.tableView.reloadData()
                    }
                }
            })
        }
        
        let editAction = UITableViewRowAction(style: .normal, title: "Edit") { (action, indexPath) in
            // TODO: show edit view
        }
        return [deleteAction, editAction]
    }
    
    
}
