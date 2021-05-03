/*****************************************************************************
 * QueueViewController.swift
 *
 * Copyright © 2020 VLC authors and VideoLAN
 *
 * Authors: Soomin Lee <bubu@mikan.io>
 *          Edgar Fouillet <vlc # edgar.fouillet.eu>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

@objc(VLCQueueViewControllerDelegate)
protocol QueueViewControllerDelegate {
    func queueViewControllerDidDisappear(_ queueViewController: QueueViewController?)
}

class QueueViewFlowLayout: UICollectionViewFlowLayout {
    override init() {
        super.init()
        self.minimumLineSpacing = 10
        self.minimumInteritemSpacing = 0
        self.sectionHeadersPinToVisibleBounds = true
        self.scrollDirection = .vertical
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        return true
    }
}

@objc(VLCQueueViewController)
class QueueViewController: UIViewController {
    @IBOutlet weak var queueCollectionView: UICollectionView!
    @IBOutlet weak var topView: UIVisualEffectView!
    @IBOutlet weak var grabberView: UIView!

    private var scrolledCellIndex: IndexPath = IndexPath()

    private let cellHeight: CGFloat = 56

    private let sidePadding: CGFloat = 10
    private let topPadding: CGFloat = 8
    private let bottomPadding: CGFloat = 8

    private let darkOverlayAlpha: CGFloat = 0.6

    private var originY: CGFloat = 0

    private var playbackService: PlaybackService {
        get {
            PlaybackService.sharedInstance()
        }
    }
    private var mediaList: VLCMediaList {
        get {
            PlaybackService.sharedInstance().mediaList
        }
    }

    private let medialibraryService: MediaLibraryService

    private lazy var collectionViewLayout = QueueViewFlowLayout()
    private var constraints: [NSLayoutConstraint] = []
    private var topConstraint: NSLayoutConstraint?
    private var topConstraintConstant: CGFloat {
        if parent is VideoPlayerViewController || parent is VLCMovieViewController {
            return 50
        } else {
            return 0
        }
    }

    private var darkOverlayView: UIView = UIView()
    private var darkOverlayViewConstraints: [NSLayoutConstraint] = []

    private let animationDuration = 0.2

    private lazy var longPressGesture: UILongPressGestureRecognizer = {
        let longPressGesture = UILongPressGestureRecognizer(target: self,
                                                            action: #selector(handleLongPress))
        return longPressGesture
    }()

    @objc weak var delegate: QueueViewControllerDelegate?

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return PresentationTheme.darkTheme.colors.statusBarStyle
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        initViews()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(themeDidChange),
                                               name: .VLCThemeDidChangeNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(deviceOrientationDidChange),
                                               name: UIDevice.orientationDidChangeNotification,
                                               object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        delegate?.queueViewControllerDidDisappear(self)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        view.alpha = 0.0
        topView.isHidden = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    override func didMove(toParent parent: UIViewController?) {
        view.setNeedsLayout()
        view.layoutIfNeeded()
        NSLayoutConstraint.deactivate(darkOverlayViewConstraints)
        NSLayoutConstraint.deactivate(constraints)
        darkOverlayViewConstraints.removeAll()
        constraints.removeAll()

        if let parent = parent {
            parent.view.addSubview(darkOverlayView)
            darkOverlayViewConstraints = [
                darkOverlayView.topAnchor.constraint(equalTo: parent.view.topAnchor),
                darkOverlayView.leadingAnchor.constraint(equalTo: parent.view.leadingAnchor),
                darkOverlayView.trailingAnchor.constraint(equalTo: parent.view.trailingAnchor),
                darkOverlayView.bottomAnchor.constraint(equalTo: parent.view.bottomAnchor)
            ]

            let heightConstraint: NSLayoutConstraint?
            let bottomConstraint: NSLayoutConstraint?
            if let parent = parent as? VLCPlayerDisplayController, let miniPlaybackView = parent.miniPlaybackView as? AudioMiniPlayer {
                parent.view.bringSubviewToFront(miniPlaybackView)
                topConstraint = view.topAnchor.constraint(equalTo: miniPlaybackView.bottomAnchor)
                let topInset: CGFloat = miniPlaybackView.miniPlayerTopPosition(in: parent.view)
                heightConstraint = view.heightAnchor.constraint(equalTo: parent.view.heightAnchor,
                                                                constant: -(miniPlaybackView.frame.height + topInset))
                bottomConstraint = nil
            } else {
                if #available(iOS 11.0, *) {
                    topConstraint = view.topAnchor.constraint(equalTo: parent.view.safeAreaLayoutGuide.topAnchor, constant: topConstraintConstant)
                } else {
                    topConstraint = view.topAnchor.constraint(equalTo: parent.view.topAnchor, constant: topConstraintConstant)
                }
                heightConstraint = nil
                bottomConstraint = view.bottomAnchor.constraint(equalTo: parent.view.bottomAnchor)
            }
            parent.view.addSubview(view)
            constraints = [
                view.leadingAnchor.constraint(equalTo: parent.view.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: parent.view.trailingAnchor)
            ]
            if let topConstraint = topConstraint {
                constraints.append(topConstraint)
            }

            if let heightConstraint = heightConstraint {
                constraints.append(heightConstraint)
            }
            if let bottomConstraint = bottomConstraint {
                constraints.append(bottomConstraint)
            }

            NSLayoutConstraint.activate(darkOverlayViewConstraints)
            NSLayoutConstraint.activate(constraints)
            view.layoutIfNeeded()
            reload()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        topConstraint?.constant = topConstraintConstant
        reload()
    }

    @objc init(medialibraryService: MediaLibraryService) {
        self.medialibraryService = medialibraryService
        super.init(nibName: nil, bundle: nil)
        view.alpha = 0.0
    }

    @objc func show() {
        UIView.animate(withDuration: animationDuration, animations: {
            self.view.alpha = 1.0
            self.darkOverlayView.isHidden = false
        })
    }

    @objc func hide() {
        UIView.animate(withDuration: animationDuration, animations: {
            self.view.alpha = 0.0
            self.darkOverlayView.isHidden = true
        })
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @IBAction func didDrag(_ sender: UIPanGestureRecognizer) {
        switch sender.state {
            case .began:
                dragDidBegin(sender)
            case .changed:
                dragStateDidChange(sender)
            case .ended:
                dragDidEnd(sender)
            default:
                break
        }
    }

    func dragDidBegin(_ sender: UIPanGestureRecognizer) {
        originY = view.frame.origin.y
    }

    func dragStateDidChange(_ sender: UIPanGestureRecognizer) {
        let translation = sender.translation(in: parent?.view)
        if let topConstraint = topConstraint {
            topConstraint.constant = max(0.0, topConstraint.constant + translation.y)
        }
        sender.setTranslation(CGPoint.zero, in: parent?.view)
        if let parent = parent as? VLCMovieViewController {
            darkOverlayView.alpha = max(0.0, darkOverlayAlpha - view.frame.minY / parent.view.frame.maxY)
        } else if let parent = parent as? VideoPlayerViewController {
            darkOverlayView.alpha = max(0.0, darkOverlayAlpha - view.frame.minY / parent.view.frame.maxY)
        }
    }

    func dragDidEnd(_ sender: UIPanGestureRecognizer) {
        if let parent = parent {
            if self.view.frame.minY > parent.view.frame.maxY / 2 {
                dismissPlayqueue()
            } else {
                showPlayqueue()
            }
        }
    }

    private func showPlayqueue() {
        topConstraint?.constant = topConstraintConstant
        UIView.animate(withDuration: animationDuration, animations: {
            self.view.layoutIfNeeded()
        })
    }

    private func dismissPlayqueue() {
        if let parent = parent {
            let newY: CGFloat = parent.view.frame.maxY
            topConstraint?.constant = newY - originY
            UIView.animate(withDuration: animationDuration, animations: {
                self.view.layoutIfNeeded()
            }, completion: { _ in
                self.dismissPlayqueueCompletion(in: parent)
            })
        }
    }

    func dismissPlayqueueCompletion(in parent: UIViewController) {
        view.alpha = 0.0
        view.removeFromSuperview()
        removeFromParent()
        darkOverlayView.isHidden = true
        darkOverlayView.alpha = darkOverlayAlpha
    }

    @objc func deviceOrientationDidChange(_ notification: Notification) {
        queueCollectionView.collectionViewLayout.invalidateLayout()
    }

    private func reload() {
        queueCollectionView.reloadData()
        queueCollectionView.collectionViewLayout.invalidateLayout()
    }
}

// MARK: - Private initializers

private extension QueueViewController {
    private func initViews() {
        Bundle.main.loadNibNamed("QueueView", owner: self, options: nil)
        view.backgroundColor = PresentationTheme.current.colors.background
        view.translatesAutoresizingMaskIntoConstraints = false
        initDarkOverlayView()
        initQueueCollectionView()
        topView.alpha = 0.1
        themeDidChange()
        grabberView.layer.cornerRadius = 2.5
    }

    private func initDarkOverlayView() {
        darkOverlayView.backgroundColor = .black
        darkOverlayView.alpha = darkOverlayAlpha
        darkOverlayView.isHidden = true
        darkOverlayView.translatesAutoresizingMaskIntoConstraints = false
    }

    private func initQueueCollectionView() {
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 4
        queueCollectionView.translatesAutoresizingMaskIntoConstraints = false
        let cellNib = UINib(nibName: MediaCollectionViewCell.nibName, bundle: nil)
        queueCollectionView.register(cellNib,
                                     forCellWithReuseIdentifier: MediaCollectionViewCell.defaultReuseIdentifier)
        queueCollectionView.delegate = self
        queueCollectionView.dataSource = self
        queueCollectionView.addGestureRecognizer(longPressGesture)
        queueCollectionView.collectionViewLayout = collectionViewLayout
        queueCollectionView.backgroundColor = PresentationTheme.current.colors.background
    }
}

// MARK: - Private handlers

private extension QueueViewController {
    @objc private func themeDidChange() {
        view.backgroundColor = PresentationTheme.current.colors.background
        queueCollectionView.backgroundColor = PresentationTheme.current.colors.background
        setNeedsStatusBarAppearanceUpdate()
    }

    private func updateCollectionViewCellApparence(_ cell: MediaCollectionViewCell, isSelected: Bool) {
        var textColor = PresentationTheme.current.colors.cellTextColor
        var tintColor = PresentationTheme.current.colors.cellDetailTextColor

        if isSelected {
            textColor = PresentationTheme.current.colors.orangeUI
            tintColor = PresentationTheme.current.colors.orangeUI
        }

        cell.tintColor = tintColor
        cell.titleLabel.textColor = textColor
    }

    @objc private func handleLongPress(gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            guard let selectedIndexPath = queueCollectionView.indexPathForItem(at:
                gesture.location(in: queueCollectionView)) else {
                    break
            }
            queueCollectionView.beginInteractiveMovementForItem(at: selectedIndexPath)
        case .changed:
            var location = gesture.location(in: gesture.view)
            location.x = queueCollectionView.frame.width / 2
            queueCollectionView.updateInteractiveMovementTargetPosition(location)
        case .ended:
            queueCollectionView.endInteractiveMovement()
        default:
            queueCollectionView.cancelInteractiveMovement()
        }
    }

    @objc private func dismissView() {
        dismiss(animated: true) {
            [weak self] in
            self?.delegate?.queueViewControllerDidDisappear(self)
        }
    }
}

// MARK: - UICollectionViewFlowLayout

extension QueueViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.frame.width - (sidePadding * 2), height: cellHeight)
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        insetForSectionAt section: Int) -> UIEdgeInsets {
        let grabberHeight = topView.isHidden ? 0 : topView.frame.height
        return UIEdgeInsets(top: topPadding + grabberHeight, left: sidePadding, bottom: bottomPadding, right: sidePadding)
    }
}

// MARK: - UICollectionViewDelegate / MediaCollectionViewCellDelegate

extension QueueViewController: UICollectionViewDelegate, MediaCollectionViewCellDelegate {
    private func selectedItem(in collectionView: UICollectionView, at indexPath: IndexPath) {
        guard indexPath.row <= mediaList.count else {
            assertionFailure("QueueViewController: didSelectItemAt: IndexPath out of range.")
            return
        }
        playbackService.playItem(at: UInt(indexPath.row))
        guard let cell = collectionView.cellForItem(at: indexPath) as? MediaCollectionViewCell else {
            assertionFailure("QueueViewController: didSelectItemAt: Cell not a MediaCollectionViewCell")
            return
        }
        updateCollectionViewCellApparence(cell, isSelected: true)
        reload()
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedItem(in: collectionView, at: indexPath)
    }

    func collectionView(_ collectionView: UICollectionView,
                        targetIndexPathForMoveFromItemAt originalIndexPath: IndexPath,
                        toProposedIndexPath proposedIndexPath: IndexPath) -> IndexPath {
        return proposedIndexPath
    }

    func mediaCollectionViewCellHandleDelete(of cell: MediaCollectionViewCell) {
        guard let indexPath = queueCollectionView.indexPath(for: cell) else {
            return
        }
        resetScrollView({ _ in
            self.mediaList.removeMedia(at: UInt(indexPath.row))
            self.reload()
        })
    }

    func mediaCollectionViewCellMediaTapped(in cell: MediaCollectionViewCell) {
        guard let indexPath = queueCollectionView.indexPath(for: cell) else {
            return
        }
        selectedItem(in: queueCollectionView, at: indexPath)
    }

    func mediaCollectionViewCellSetScrolledCellIndex(of cell: MediaCollectionViewCell?) {
        if let cell = cell {
            guard let indexPath = queueCollectionView.indexPath(for: cell) else {
                return
            }

            scrolledCellIndex = indexPath
        }
    }

    func mediaCollectionViewCellGetScrolledCell() -> MediaCollectionViewCell? {
        if scrolledCellIndex.isEmpty {
            return nil
        }

        let cell = queueCollectionView.cellForItem(at: scrolledCellIndex)
        if let cell = cell as? MediaCollectionViewCell {
            return cell
        }

        return nil
    }
}

// MARK: - UIScrollViewDelegate

extension QueueViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.contentOffset.y <= 5.0 {
            topView.alpha = max(0.1, scrollView.contentOffset.y / 5)
        } else {
            topView.alpha = 1.0
        }
    }

    private func resetScrollView(_ completion: ((Bool) -> Void)? = nil) {
        if let mediaCell = mediaCollectionViewCellGetScrolledCell() {
            mediaCell.resetScrollView(completion)
        }
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        resetScrollView()
    }
}

// MARK: - UICollectionViewDataSource

extension QueueViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        return mediaList.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        canMoveItemAt indexPath: IndexPath) -> Bool {
        return true
    }

    func collectionView(_ collectionView: UICollectionView,
                        moveItemAt sourceIndexPath: IndexPath,
                        to destinationIndexPath: IndexPath) {
        guard sourceIndexPath.row <= mediaList.count
            && destinationIndexPath.row <= mediaList.count else {
            assertionFailure("QueueViewController: moveItemAt: IndexPath out of range.")
            return
        }
        mediaList.lock()
        let currentMedia = mediaList.media(at: UInt(sourceIndexPath.row))
        if mediaList.removeMedia(at: UInt(sourceIndexPath.row)) {
            mediaList.insert(currentMedia, at: UInt(destinationIndexPath.row))
        }
        mediaList.unlock()
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell =
            collectionView.dequeueReusableCell(withReuseIdentifier: MediaCollectionViewCell.defaultReuseIdentifier,
                                               for: indexPath) as? MediaCollectionViewCell else {
                                                return UICollectionViewCell()
        }

        guard indexPath.row <= mediaList.count else {
            assertionFailure("QueueViewController: cellForItemAt: IndexPath out of range.")
            return UICollectionViewCell()
        }

        cell.delegate = self

        var media: VLCMedia?

        cell.newLabel.isHidden = true
        cell.dragIndicatorImageView.isHidden = false
        media = mediaList.media(at: UInt(indexPath.row))

        let isSelected = playbackService.currentlyPlayingMedia == media
        updateCollectionViewCellApparence(cell, isSelected: isSelected)

        guard let safeMedia = media else {
            assertionFailure("QueueViewController: cellForItemAt: Failed to fetch media")
            return cell
        }
        if let media = medialibraryService.fetchMedia(with: safeMedia.url) {
            cell.media = media
        } else if let media = medialibraryService.medialib.addExternalMedia(withMrl: safeMedia.url) {
            cell.media = media
        }
        return cell
    }
}

// MARK: - VLCMediaListDelegate

extension QueueViewController: VLCMediaListDelegate {
    func mediaList(_ aMediaList: VLCMediaList!, mediaAdded media: VLCMedia!, at index: UInt) {
        reload()
    }

    func mediaList(_ aMediaList: VLCMediaList!, mediaRemovedAt index: UInt) {
        reload()
    }
}
