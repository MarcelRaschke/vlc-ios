import Foundation
/*****************************************************************************
 * MediaLibraryBaseModel.swift
 *
 * Copyright © 2018 VLC authors and VideoLAN
 * Copyright © 2018 Videolabs
 *
 * Authors: Soomin Lee <bubu@mikan.io>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

@objc(VLCMediaLibraryBaseModelObserver)
protocol MediaLibraryBaseModelObserver {
    func mediaLibraryBaseModelReloadView()
    @objc optional func mediaLibraryBaseModelReload(at indexPaths: [IndexPath])
    @objc optional func mediaLibraryBaseModelPopView()
}

// Expose a "shadow" version without associatedType in order to use it as a type
protocol MediaLibraryBaseModel {
    init(medialibrary: MediaLibraryService)

    var anyfiles: [VLCMLObject] { get }

    var sortModel: SortModel { get }

    var indicatorName: String { get }
    
    #if !os(watchOS)
    var cellType: BaseCollectionViewCell.Type { get }
    #endif

    func anyAppend(_ item: VLCMLObject)
    func anyDelete(_ items: [VLCMLObject])
    func sort(by criteria: VLCMLSortingCriteria, desc: Bool)

    // Give a name to a model to identify each model programmatically
    var name: String { get }
}

protocol MLBaseModel: AnyObject, MediaLibraryBaseModel {
    associatedtype MLType where MLType: VLCMLObject

    init(medialibrary: MediaLibraryService)

    var fileArrayLock: NSRecursiveLock { get }
    var files: [MLType] { get set }

    var medialibrary: MediaLibraryService { get }

    var observable: VLCObservable<MediaLibraryBaseModelObserver> { get }

    var indicatorName: String { get }

    func append(_ item: MLType)
    func delete(_ items: [MLType])
    func sort(by criteria: VLCMLSortingCriteria, desc: Bool)
}

extension MLBaseModel {
    var anyfiles: [VLCMLObject] {
        return files
    }

    func anyAppend(_ item: VLCMLObject) {
        guard let item = item as? MLType else {
            preconditionFailure("MLBaseModel: Wrong underlying ML type.")
        }
        append(item)
    }

    func anyDelete(_ items: [VLCMLObject]) {
        guard let items = items as? [MLType] else {
            preconditionFailure("MLBaseModel: Wrong underlying ML type.")
        }
        delete(items)
    }

    func sort(by criteria: VLCMLSortingCriteria, desc: Bool) {
        fatalError()
    }
}

protocol SearchableMLModel {
    func contains(_ searchString: String) -> Bool
}

extension SearchableMLModel {
    func search(_ searchString: String, in fullString: String) -> Bool {
        do {
            let separatedString = searchString.components(separatedBy: " ")

            let matches = try separatedString.allSatisfy { pattern in
                guard !pattern.isEmpty else { return true }

                let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .ignoreMetacharacters])
                let numberOfMatches = regex.numberOfMatches(in: fullString, range: NSRange(location: 0, length: fullString.count))
                return numberOfMatches > 0
            }

            return matches
        } catch {
            return false
        }
    }
}

protocol MediaCollectionModel {
    func files(with criteria: VLCMLSortingCriteria,
               desc: Bool) -> [VLCMLMedia]?
    func sortModel() -> SortModel?
    func title() -> String
    func numberOfTracksString() -> String
}

// MARK: - Helper methods

extension MLBaseModel {
    /// Swap the given [MLType] to the cached array.
    /// This only swaps models with the same VLCMLIdentifiers
    /// - Parameter models: To be swapped models
    /// - Returns: New array of `MLType` if changes have been made, else return a unchanged cached version.
    func swapModels(with models: [MLType]) -> [MLType] {
        var newFiles = files

        // FIXME: This should be handled in a thread safe way
        for var model in models {
            for (currentMediaIndex, file) in files.enumerated()
                where file.identifier() == model.identifier() {
                    swap(&newFiles[currentMediaIndex], &model)
                    break
            }
        }
        return newFiles
    }

    func filterFilesFromDeletion(of items: [VLCMLObject]) {
        files = files.filter() {
            for item in items where $0.identifier() == item.identifier() {
                return false
            }
            return true
        }
    }

    func filterFilesFromDeletion(of ids: [VLCMLIdentifier]) {
        files = files.filter() {
            return !ids.contains($0.identifier())
        }
    }
}

extension VLCMLObject {
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.identifier() == rhs.identifier()
    }
}

extension MediaCollectionModel {
    func files(with criteria: VLCMLSortingCriteria = .default,
               desc: Bool = false) -> [VLCMLMedia]? {
        return files(with: criteria, desc: desc)
    }

    func thumbnail() -> UIImage? {
        var image: UIImage? = nil
        if image == nil {
            for track in files() ?? [] where track.thumbnailStatus() == .available {
                image = VLCThumbnailsCache.thumbnail(for: track.thumbnail())
                break
            }
        }
        if image == nil
            || (!UserDefaults.standard.bool(forKey: kVLCSettingShowThumbnails) && self is VLCMLMediaGroup)
            || (!UserDefaults.standard.bool(forKey: kVLCSettingShowArtworks) && !(self is VLCMLMediaGroup)) {
            #if !os(watchOS)
            let isDarktheme = PresentationTheme.current.isDark
            #elseif os(watchOS)
            // watchOS only has a dark theme
            let isDarktheme = true
            #endif
            if self is VLCMLMediaGroup {
                image = isDarktheme ? UIImage(named: "movie-placeholder-dark") : UIImage(named: "movie-placeholder-white")
            } else if self is VLCMLArtist {
                image = isDarktheme ? UIImage(named: "artist-placeholder-dark") : UIImage(named: "artist-placeholder-white")
            } else {
                image = isDarktheme ? UIImage(named: "album-placeholder-dark") : UIImage(named: "album-placeholder-white")
            }
        }
        return image
    }
}
