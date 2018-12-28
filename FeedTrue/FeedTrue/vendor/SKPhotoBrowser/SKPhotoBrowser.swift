//
//  SKPhotoBrowser.swift
//  SKViewExample
//
//  Created by suzuki_keishi on 2015/10/01.
//  Copyright © 2015 suzuki_keishi. All rights reserved.
//

import UIKit

public let SKPHOTO_LOADING_DID_END_NOTIFICATION = "photoLoadingDidEndNotification"
public let iconSize: CGFloat = 44

// MARK: - SKPhotoBrowser
open class SKPhotoBrowser: UIViewController {
    // open function
    open var currentPageIndex: Int = 0
    open var activityItemProvider: UIActivityItemProvider?
    open var photos: [SKPhotoProtocol] = []
    var feedInfo: FTFeedInfo?
    
    internal lazy var pagingScrollView: SKPagingScrollView = SKPagingScrollView(frame: self.view.frame, browser: self)
    
    // appearance
    fileprivate let bgColor: UIColor = SKPhotoBrowserOptions.backgroundColor
    // animation
    fileprivate let animator: SKAnimator = .init()
    
    fileprivate var actionView: SKActionView!
    fileprivate(set) var paginationView: SKPaginationView!
    fileprivate var toolbar: SKToolbar!
    
    //fileprivate(set) var reactionViewController: FTDetailFileViewController!
    //fileprivate(set) var reactionView: UIView!

    // actions
    fileprivate var activityViewController: UIActivityViewController!
    fileprivate var panGesture: UIPanGestureRecognizer?
    
    fileprivate var saveImageView: UIImageView!
    fileprivate var commentButton: MIBadgeButton!
    fileprivate var loveButton: MIBadgeButton!
    fileprivate var avatarImageView: UIImageView!

    // for status check property
    fileprivate var isEndAnimationByToolBar: Bool = true
    fileprivate var isViewActive: Bool = false
    fileprivate var isPerformingLayout: Bool = false
    
    // pangesture property
    fileprivate var firstX: CGFloat = 0.0
    fileprivate var firstY: CGFloat = 0.0
    
    // timer
    fileprivate var controlVisibilityTimer: Timer!
    
    // delegate
    open weak var delegate: SKPhotoBrowserDelegate?

    // statusbar initial state
    private var statusbarHidden: Bool = UIApplication.shared.isStatusBarHidden
    
    // strings
    open var cancelTitle = "Cancel"
    
    // MARK: - Initializer
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    public override init(nibName nibNameOrNil: String!, bundle nibBundleOrNil: Bundle!) {
        super.init(nibName: nil, bundle: nil)
        setup()
    }
    
    public convenience init(photos: [SKPhotoProtocol]) {
        self.init(photos: photos, initialPageIndex: 0)
    }
    
    @available(*, deprecated: 5.0.0)
    public convenience init(originImage: UIImage, photos: [SKPhotoProtocol], animatedFromView: UIView) {
        self.init(nibName: nil, bundle: nil)
        self.photos = photos
        self.photos.forEach { $0.checkCache() }
        animator.senderOriginImage = originImage
        animator.senderViewForAnimation = animatedFromView
    }
    
    public convenience init(photos: [SKPhotoProtocol], initialPageIndex: Int) {
        self.init(nibName: nil, bundle: nil)
        self.photos = photos
        self.photos.forEach { $0.checkCache() }
        self.currentPageIndex = min(initialPageIndex, photos.count - 1)
        animator.senderOriginImage = photos[currentPageIndex].underlyingImage
        animator.senderViewForAnimation = photos[currentPageIndex] as? UIView
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func setup() {
        modalPresentationCapturesStatusBarAppearance = true
        modalPresentationStyle = .custom
        modalTransitionStyle = .crossDissolve
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleSKPhotoLoadingDidEndNotification(_:)),
                                               name: NSNotification.Name(rawValue: SKPHOTO_LOADING_DID_END_NOTIFICATION),
                                               object: nil)
    }
    
    // MARK: - override
    override open func viewDidLoad() {
        super.viewDidLoad()
        configureAppearance()
        configurePagingScrollView()
        configureGestureControl()
        configureActionView()
        configurePaginationView()
        configureToolbar()

        animator.willPresent(self)
    }
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        reloadData()
        
        var i = 0
        for photo: SKPhotoProtocol in photos {
            photo.index = i
            i += 1
        }
    }
    
    override open func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        isPerformingLayout = true
        // where did start
        delegate?.didShowPhotoAtIndex?(self, index: currentPageIndex)

        // toolbar
        toolbar.frame = frameForToolbarAtOrientation()
        
        // action
        actionView.updateFrame(frame: view.frame)

        // paging
        paginationView.updateFrame(frame: view.frame)
        pagingScrollView.updateFrame(view.bounds, currentPageIndex: currentPageIndex)
        //reactionViewController.updateFrame(frame: view.frame)
        isPerformingLayout = false
    }
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        isViewActive = true
    }
    
    override open var prefersStatusBarHidden: Bool {
        return !SKPhotoBrowserOptions.displayStatusbar
    }
    
    // MARK: - Notification
    @objc open func handleSKPhotoLoadingDidEndNotification(_ notification: Notification) {
        guard let photo = notification.object as? SKPhotoProtocol else {
            return
        }
        
        DispatchQueue.main.async(execute: {
            guard let page = self.pagingScrollView.pageDisplayingAtPhoto(photo), let photo = page.photo else {
                return
            }
            
            if photo.underlyingImage != nil {
                page.displayImage(complete: true)
                self.loadAdjacentPhotosIfNecessary(photo)
            } else {
                page.displayImageFailure()
            }
        })
    }
    
    open func loadAdjacentPhotosIfNecessary(_ photo: SKPhotoProtocol) {
        pagingScrollView.loadAdjacentPhotosIfNecessary(photo, currentPageIndex: currentPageIndex)
    }
    
    // MARK: - initialize / setup
    open func reloadData() {
        performLayout()
        view.setNeedsLayout()
    }
    
    open func performLayout() {
        isPerformingLayout = true

        // reset local cache
        pagingScrollView.reload()
        pagingScrollView.updateContentOffset(currentPageIndex)
        pagingScrollView.tilePages()
        
        delegate?.didShowPhotoAtIndex?(self, index: currentPageIndex)
        
        isPerformingLayout = false
    }
    
    open func prepareForClosePhotoBrowser() {
        cancelControlHiding()
        if let panGesture = panGesture {
            view.removeGestureRecognizer(panGesture)
        }
        NSObject.cancelPreviousPerformRequests(withTarget: self)
    }
    
    open func dismissPhotoBrowser(animated: Bool, completion: (() -> Void)? = nil) {
        prepareForClosePhotoBrowser()
        if !animated {
            modalTransitionStyle = .crossDissolve
        }
        dismiss(animated: !animated) {
            completion?()
            self.delegate?.didDismissAtPageIndex?(self.currentPageIndex)
        }
    }
    
    open func determineAndClose() {
        delegate?.willDismissAtPageIndex?(self.currentPageIndex)
        animator.willDismiss(self)
    }
    
    open func popupShare(includeCaption: Bool = true) {
        let photo = photos[currentPageIndex]
        guard let underlyingImage = photo.underlyingImage else {
            return
        }
        
        var activityItems: [AnyObject] = [underlyingImage]
        if photo.caption != nil && includeCaption {
            if let shareExtraCaption = SKPhotoBrowserOptions.shareExtraCaption {
                let caption = photo.caption ?? "" + shareExtraCaption
                activityItems.append(caption as AnyObject)
            } else {
                activityItems.append(photo.caption as AnyObject)
            }
        }
        
        if let activityItemProvider = activityItemProvider {
            activityItems.append(activityItemProvider)
        }
        
        activityViewController = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        activityViewController.completionWithItemsHandler = { (activity, success, items, error) in
            self.hideControlsAfterDelay()
            self.activityViewController = nil
        }
        if UI_USER_INTERFACE_IDIOM() == .phone {
            present(activityViewController, animated: true, completion: nil)
        } else {
            activityViewController.modalPresentationStyle = .popover
            let popover: UIPopoverPresentationController! = activityViewController.popoverPresentationController
            popover.barButtonItem = toolbar.toolActionButton
            present(activityViewController, animated: true, completion: nil)
        }
    }
}

// MARK: - Public Function For Customizing Buttons

public extension SKPhotoBrowser {
    func updateCloseButton(_ image: UIImage, size: CGSize? = nil) {
        actionView.updateCloseButton(image: image, size: size)
    }
    
    func updateDeleteButton(_ image: UIImage, size: CGSize? = nil) {
        actionView.updateDeleteButton(image: image, size: size)
    }
}

// MARK: - Public Function For Browser Control

public extension SKPhotoBrowser {
    func initializePageIndex(_ index: Int) {
        let i = min(index, photos.count - 1)
        currentPageIndex = i
        
        if isViewLoaded {
            jumpToPageAtIndex(index)
            if !isViewActive {
                pagingScrollView.tilePages()
            }
            paginationView.update(currentPageIndex)
        }
    }
    
    func jumpToPageAtIndex(_ index: Int) {
        if index < photos.count {
            if !isEndAnimationByToolBar {
                return
            }
            isEndAnimationByToolBar = false

            let pageFrame = frameForPageAtIndex(index)
            pagingScrollView.jumpToPageAtIndex(pageFrame)
        }
        hideControlsAfterDelay()
    }
    
    func photoAtIndex(_ index: Int) -> SKPhotoProtocol {
        return photos[index]
    }
    
    @objc func gotoPreviousPage() {
        jumpToPageAtIndex(currentPageIndex - 1)
    }
    
    @objc func gotoNextPage() {
        jumpToPageAtIndex(currentPageIndex + 1)
    }
    
    func cancelControlHiding() {
        if controlVisibilityTimer != nil {
            controlVisibilityTimer.invalidate()
            controlVisibilityTimer = nil
        }
    }
    
    func hideControlsAfterDelay() {
        // reset
        cancelControlHiding()
        // start
        controlVisibilityTimer = Timer.scheduledTimer(timeInterval: 4.0, target: self, selector: #selector(SKPhotoBrowser.hideControls(_:)), userInfo: nil, repeats: false)
    }
    
    func hideControls() {
        setControlsHidden(true, animated: true, permanent: false)
    }
    
    @objc func hideControls(_ timer: Timer) {
        hideControls()
        delegate?.controlsVisibilityToggled?(self, hidden: true)
    }
    
    func toggleControls() {
        let hidden = !areControlsHidden()
        setControlsHidden(hidden, animated: true, permanent: false)
        delegate?.controlsVisibilityToggled?(self, hidden: areControlsHidden())
    }
    
    func areControlsHidden() -> Bool {
        return paginationView.alpha == 0.0
    }
    
    func getCurrentPageIndex() -> Int {
        return currentPageIndex
    }
    
    func addPhotos(photos: [SKPhotoProtocol]) {
        self.photos.append(contentsOf: photos)
        self.reloadData()
    }
    
    func insertPhotos(photos: [SKPhotoProtocol], at index: Int) {
        self.photos.insert(contentsOf: photos, at: index)
        self.reloadData()
    }
}

// MARK: - Internal Function

internal extension SKPhotoBrowser {
    func showButtons() {
        actionView.animate(hidden: false)
    }
    
    func pageDisplayedAtIndex(_ index: Int) -> SKZoomingScrollView? {
        return pagingScrollView.pageDisplayedAtIndex(index)
    }
    
    func getImageFromView(_ sender: UIView) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(sender.frame.size, true, 0.0)
        sender.layer.render(in: UIGraphicsGetCurrentContext()!)
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result!
    }
}

// MARK: - Internal Function For Frame Calc

internal extension SKPhotoBrowser {
    func frameForToolbarAtOrientation() -> CGRect {
        let offset: CGFloat = {
            if #available(iOS 11.0, *) {
                return view.safeAreaInsets.bottom
            } else {
                return 15
            }
        }()
        return view.bounds.divided(atDistance: 44, from: .maxYEdge).slice.offsetBy(dx: 0, dy: -offset)
    }
    
    func frameForToolbarHideAtOrientation() -> CGRect {
        return view.bounds.divided(atDistance: 44, from: .maxYEdge).slice.offsetBy(dx: 0, dy: 44)
    }
    
    func frameForPageAtIndex(_ index: Int) -> CGRect {
        let bounds = pagingScrollView.bounds
        var pageFrame = bounds
        pageFrame.size.width -= (2 * 10)
        pageFrame.origin.x = (bounds.size.width * CGFloat(index)) + 10
        return pageFrame
    }
}

// MARK: - Internal Function For Button Pressed, UIGesture Control

internal extension SKPhotoBrowser {
    @objc func panGestureRecognized(_ sender: UIPanGestureRecognizer) {
        guard let zoomingScrollView: SKZoomingScrollView = pagingScrollView.pageDisplayedAtIndex(currentPageIndex) else {
            return
        }
        
        animator.backgroundView.isHidden = true
        let viewHeight: CGFloat = zoomingScrollView.frame.size.height
        let viewHalfHeight: CGFloat = viewHeight/2
        var translatedPoint: CGPoint = sender.translation(in: self.view)
        
        // gesture began
        if sender.state == .began {
            firstX = zoomingScrollView.center.x
            firstY = zoomingScrollView.center.y
            
            hideControls()
            setNeedsStatusBarAppearanceUpdate()
        }
        
        translatedPoint = CGPoint(x: firstX, y: firstY + translatedPoint.y)
        zoomingScrollView.center = translatedPoint
        
        let minOffset: CGFloat = viewHalfHeight / 4
        let offset: CGFloat = 1 - (zoomingScrollView.center.y > viewHalfHeight
            ? zoomingScrollView.center.y - viewHalfHeight
            : -(zoomingScrollView.center.y - viewHalfHeight)) / viewHalfHeight
        
        view.backgroundColor = bgColor.withAlphaComponent(max(0.7, offset))
        
        // gesture end
        if sender.state == .ended {
            
            if zoomingScrollView.center.y > viewHalfHeight + minOffset
                || zoomingScrollView.center.y < viewHalfHeight - minOffset {
                
                determineAndClose()
                
            } else {
                // Continue Showing View
                setNeedsStatusBarAppearanceUpdate()
                view.backgroundColor = bgColor

                let velocityY: CGFloat = CGFloat(0.35) * sender.velocity(in: self.view).y
                let finalX: CGFloat = firstX
                let finalY: CGFloat = viewHalfHeight
                
                let animationDuration: Double = Double(abs(velocityY) * 0.0002 + 0.2)
                
                UIView.beginAnimations(nil, context: nil)
                UIView.setAnimationDuration(animationDuration)
                UIView.setAnimationCurve(UIViewAnimationCurve.easeIn)
                zoomingScrollView.center = CGPoint(x: finalX, y: finalY)
                UIView.commitAnimations()
            }
        }
    }
   
    @objc func actionButtonPressed(ignoreAndShare: Bool) {
        delegate?.willShowActionSheet?(currentPageIndex)
        
        guard photos.count > 0 else {
            return
        }
        
        if let titles = SKPhotoBrowserOptions.actionButtonTitles {
            let actionSheetController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            actionSheetController.addAction(UIAlertAction(title: cancelTitle, style: .cancel))
            
            for idx in titles.indices {
                actionSheetController.addAction(UIAlertAction(title: titles[idx], style: .default, handler: { (_) -> Void in
                    self.delegate?.didDismissActionSheetWithButtonIndex?(idx, photoIndex: self.currentPageIndex)
                }))
            }
            
            if UI_USER_INTERFACE_IDIOM() == .phone {
                present(actionSheetController, animated: true, completion: nil)
            } else {
                actionSheetController.modalPresentationStyle = .popover
                
                if let popoverController = actionSheetController.popoverPresentationController {
                    popoverController.sourceView = self.view
                    popoverController.barButtonItem = toolbar.toolActionButton
                }
                
                present(actionSheetController, animated: true, completion: { () -> Void in
                })
            }
            
        } else {
            popupShare()
        }
    }
    
    func deleteImage() {
        defer {
            reloadData()
        }
        
        if photos.count > 1 {
            pagingScrollView.deleteImage()
            
            photos.remove(at: currentPageIndex)
            if currentPageIndex != 0 {
                gotoPreviousPage()
            }
            paginationView.update(currentPageIndex)
            
        } else if photos.count == 1 {
            dismissPhotoBrowser(animated: true)
        }
    }
}

// MARK: - Private Function
private extension SKPhotoBrowser {
    func configureAppearance() {
        view.backgroundColor = bgColor
        view.clipsToBounds = true
        view.isOpaque = false
        
        if #available(iOS 11.0, *) {
            view.accessibilityIgnoresInvertColors = true
        }
    }
    
    func configurePagingScrollView() {
        pagingScrollView.delegate = self
        view.addSubview(pagingScrollView)
    }

    func configureGestureControl() {
        guard !SKPhotoBrowserOptions.disableVerticalSwipe else { return }
        
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(SKPhotoBrowser.panGestureRecognized(_:)))
        panGesture?.minimumNumberOfTouches = 1
        panGesture?.maximumNumberOfTouches = 1

        if let panGesture = panGesture {
            view.addGestureRecognizer(panGesture)
        }
    }
    
    func configureActionView() {
        actionView = SKActionView(frame: view.frame, browser: self)
        view.addSubview(actionView)
        
        let w = self.view.frame.width
        let h = self.view.frame.height
        let y: CGFloat = h - 300
        let padding: CGFloat = 64
        saveImageView = UIImageView(frame: CGRect(x: w - padding, y: y, width: iconSize, height: iconSize))
        if let saved = feedInfo?.saved, saved == true {
            saveImageView.image = UIImage.savedImage()
        } else {
            saveImageView.image = UIImage.saveImage()
        }
        
        commentButton = MIBadgeButton(frame: CGRect(x: w - padding, y: y - 64, width: iconSize, height: iconSize))
        commentButton.setImage(UIImage.commentImage(), for: .normal)
        
        if let feedCount = feedInfo?.comment?.comments?.count, feedCount > 0 {
            commentButton.badgeString = "\(feedCount)"
        } else {
            commentButton.badgeString = nil
        }
        
        commentButton.badgeBackgroundColor = UIColor.navigationBarColor()
        commentButton.badgeTextColor = UIColor.badgeTextColor()
        commentButton.badgeEdgeInsets = UIEdgeInsets(top: 8, left: -8, bottom: 0, right: 0)
        
        loveButton = MIBadgeButton(frame: CGRect(x: w - padding, y: y - 64*2, width: iconSize, height: iconSize))
        
        if feedInfo?.request_reacted != nil {
            loveButton.setImage(UIImage.lovedImage(), for: .normal)
        } else {
            loveButton.setImage(UIImage.loveImage(), for: .normal)
        }
        
        if let reactionsCount = feedInfo?.reactions?.count, reactionsCount > 0 {
            loveButton.badgeString = "\(reactionsCount)"
        } else {
            loveButton.badgeString = nil
        }
        
        loveButton.badgeBackgroundColor = UIColor.navigationBarColor()
        loveButton.badgeTextColor = UIColor.badgeTextColor()
        loveButton.badgeEdgeInsets = UIEdgeInsets(top: 8, left: -8, bottom: 0, right: 0)
        
        avatarImageView = UIImageView(frame: CGRect(x: w - padding, y: y - 64*3, width: iconSize, height: iconSize))
        
        avatarImageView.round()
        if let avatarURLString = feedInfo?.user?.avatar {
            avatarImageView.loadImage(fromURL: URL(string: avatarURLString), defaultImage: UIImage.userImage())
        } else {
            avatarImageView = UIImageView(image: UIImage.userImage())
        }
        
        view.addSubview(saveImageView)
        view.addSubview(commentButton)
        view.addSubview(loveButton)
        view.addSubview(avatarImageView)
        
        let saveTap = UITapGestureRecognizer(target: self, action: #selector(savePressed(_:)))
        saveImageView.isUserInteractionEnabled = true
        saveImageView.addGestureRecognizer(saveTap)
        
        commentButton.addTarget(self, action: #selector(commentPressed(_:)), for: .touchUpInside)
        
        loveButton.addTarget(self, action: #selector(lovePressed(_:)), for: .touchUpInside)
        
        let avatarTap = UITapGestureRecognizer(target: self, action: #selector(avatarPressed(_:)))
        avatarImageView.isUserInteractionEnabled = true
        avatarImageView.addGestureRecognizer(avatarTap)
        
        view.bringSubview(toFront: avatarImageView)
    }
    
    @objc func savePressed(_ sender: Any) {
        print(#function)
        if let saved = feedInfo?.saved, saved == true {
            // unsave
            unSave()
        } else {
            save()
        }
    }
    
    @objc func commentPressed(_ sender: Any) {
        print(#function)
        self.dismissPhotoBrowser(animated: false)
        self.delegate?.didTouchCommentButton?(self)
    }
    
    @objc func lovePressed(_ sender: Any) {
        print(#function)
        guard let feed = feedInfo else { return }
        if feed.request_reacted != nil {
            // LOVE, reactedCount += 1
            removeReaction()
        } else {
            changeReactionType()
        }
    }
    
    @objc func avatarPressed(_ sender: Any) {
        print(#function)
    }
    
    func changeReactionType() {
        guard let ct_id = feedInfo?.id else { return }
        guard let ct_name = feedInfo?.ct_name else { return }
        feedInfo?.request_reacted = "LOVE"
        loveButton.setImage(UIImage.lovedImage(), for: .normal)
        if let badgeString = loveButton.badgeString {
            let badgeCount = Int(badgeString) ?? 0
            loveButton.badgeString = "\(badgeCount + 1)"
        } else {
            loveButton.badgeString = "1"
        }
        
        WebService.share.react(ct_name: ct_name, ct_id: ct_id, react_type: FTReactionTypes.love.rawValue, completion: { (success, type) in
            if success {
                NSLog("did react successful \(type ?? "")")
                self.delegate?.feedDidChange?(self)
            } else {
                NSLog("did react failed LOVE")
                DispatchQueue.main.async {
                    self.feedInfo?.request_reacted = nil
                    self.loveButton.setImage(UIImage.loveImage(), for: .normal)
                    if let badgeString = self.loveButton.badgeString {
                        let badgeCount = Int(badgeString) ?? 0
                        self.loveButton.badgeString = badgeCount > 1 ? "\(badgeCount - 1)" : nil
                    } else {
                        print("\(#function) ERROR")
                    }
                }
            }
        })
    }
    
    func removeReaction() {
        guard let ct_id = feedInfo?.id else { return }
        guard let ct_name = feedInfo?.ct_name else { return }
        guard let requestReacted = feedInfo?.request_reacted else { return }
        feedInfo?.request_reacted = nil
        loveButton.setImage(UIImage.loveImage(), for: .normal)
        if let badgeString = loveButton.badgeString {
            let badgeCount = Int(badgeString) ?? 0
            self.loveButton.badgeString = badgeCount > 1 ? "\(badgeCount - 1)" : nil
        } else {
            print("\(#function) ERROR")
        }
        
        WebService.share.removeReact(ct_name: ct_name, ct_id: ct_id, completion: { (success, msg) in
            if success {
                NSLog("Remove react successful")
                self.delegate?.feedDidChange?(self)
            } else {
                NSLog("Remove react failed")
                DispatchQueue.main.async {
                    self.feedInfo?.request_reacted = requestReacted
                    self.loveButton.setImage(UIImage.lovedImage(), for: .normal)
                    if let badgeString = self.loveButton.badgeString {
                        let badgeCount = Int(badgeString) ?? 0
                        self.loveButton.badgeString = "\(badgeCount + 1)"
                    } else {
                        self.loveButton.badgeString = "1"
                    }
                }
            }
        })
    }
    
    func save() {
        guard let ct_id = feedInfo?.id else { return }
        guard let ct_name = feedInfo?.ct_name else { return }
        feedInfo?.saved = true
        self.saveImageView.image = UIImage.savedImage()
        WebService.share.saveFeed(ct_name: ct_name, ct_id: ct_id, completion: { (success, message) in
            if success {
                NSLog("Save Feed successful ct_name: \(ct_name) ct_id: \(ct_id)")
                self.delegate?.feedDidChange?(self)
            } else {
                NSLog("Save Feed failed ct_name: \(ct_name) ct_id: \(ct_id)")
                DispatchQueue.main.async {
                    self.feedInfo?.saved = false
                    self.saveImageView.image = UIImage.saveImage()
                }
            }
        })
    }
    
    func unSave() {
        guard let ct_id = feedInfo?.id else { return }
        guard let ct_name = feedInfo?.ct_name else { return }
        feedInfo?.saved = false
        self.saveImageView.image = UIImage.saveImage()
        WebService.share.removeSaveFeed(ct_name: ct_name, ct_id: ct_id, completion: { (success, message) in
            if success {
                NSLog("Remove saved Feed successful ct_name: \(ct_name) ct_id: \(ct_id)")
                self.delegate?.feedDidChange?(self)
            } else {
                NSLog("Remove saved Feed failed ct_name: \(ct_name) ct_id: \(ct_id)")
                DispatchQueue.main.async {
                    self.feedInfo?.saved = true
                    self.saveImageView.image = UIImage.savedImage()
                }
            }
        })
    }

    func configurePaginationView() {
        paginationView = SKPaginationView(frame: view.frame, browser: self)
        //view.addSubview(paginationView)
//        guard let feed = feedInfo else { return }
//        reactionViewController = FTDetailFileViewController(feedInfo: feed)
//        reactionView = reactionViewController.view
//        reactionViewController.willMove(toParentViewController: self)
//        self.addChildViewController(reactionViewController)
//        view.addSubview(reactionView)
//        reactionView.isUserInteractionEnabled = true
//        reactionView.clipsToBounds = true
//        reactionView.backgroundColor = .clear
//        reactionViewController.didMove(toParentViewController: self)
    }
    
    func configureToolbar() {
        toolbar = SKToolbar(frame: frameForToolbarAtOrientation(), browser: self)
        view.addSubview(toolbar)
    }

    func setControlsHidden(_ hidden: Bool, animated: Bool, permanent: Bool) {
        // timer update
        cancelControlHiding()
        
        // scroll animation
        pagingScrollView.setControlsHidden(hidden: hidden)
        //reactionViewController.setControlsHidden(hidden: hidden)
        
        // paging animation
        paginationView.setControlsHidden(hidden: hidden)
        
        // action view animation
        actionView.animate(hidden: hidden)
        setRightButtonsHidden(hidden: hidden)
        if !permanent {
            hideControlsAfterDelay()
        }
        setNeedsStatusBarAppearanceUpdate()
    }
    
    private func setRightButtonsHidden(hidden: Bool) {
        let alpha: CGFloat = hidden ? 0.0 : 1.0
        
        UIView.animate(withDuration: 0.35,
                       animations: { () -> Void in
                        self.saveImageView.alpha = alpha
                        self.commentButton.alpha = alpha
                        self.loveButton.alpha = alpha
                        self.avatarImageView.alpha = alpha
        }, completion: nil)
    }
}

// MARK: - UIScrollView Delegate

extension SKPhotoBrowser: UIScrollViewDelegate {
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard isViewActive else { return }
        guard !isPerformingLayout else { return }
        
        // tile page
        pagingScrollView.tilePages()
        
        // Calculate current page
        let previousCurrentPage = currentPageIndex
        let visibleBounds = pagingScrollView.bounds
        currentPageIndex = min(max(Int(floor(visibleBounds.midX / visibleBounds.width)), 0), photos.count - 1)
        
        if currentPageIndex != previousCurrentPage {
            delegate?.didShowPhotoAtIndex?(self, index: currentPageIndex)
            paginationView.update(currentPageIndex)
        }
    }
    
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        hideControlsAfterDelay()
        
        let currentIndex = pagingScrollView.contentOffset.x / pagingScrollView.frame.size.width
        delegate?.didScrollToIndex?(self, index: Int(currentIndex))
    }
    
    public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        isEndAnimationByToolBar = true
    }
}
