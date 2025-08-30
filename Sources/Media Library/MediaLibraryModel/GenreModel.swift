/*****************************************************************************
 * GenreModel.swift
 *
 * Copyright © 2018 VLC authors and VideoLAN
 * Copyright © 2018 Videolabs
 *
 * Authors: Soomin Lee <bubu@mikan.io>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

class GenreModel: AudioCollectionModel {
    typealias MLType = VLCMLGenre

    var sortModel = SortModel([.alpha, .playCount])

    var observable = VLCObservable<MediaLibraryBaseModelObserver>()

    var fileArrayLock = NSRecursiveLock()
    var files = [VLCMLGenre]()

    var cellType: BaseCollectionViewCell.Type {
        return UserDefaults.standard.bool(forKey: "\(kVLCAudioLibraryGridLayout)\(name)") ? MediaGridCollectionCell.self : MediaCollectionViewCell.self
    }

    var medialibrary: MediaLibraryService

    var name: String = "GENRES"

    var indicatorName: String = NSLocalizedString("GENRES", comment: "")

    required init(medialibrary: MediaLibraryService) {
        defer {
            fileArrayLock.unlock()
        }
        self.medialibrary = medialibrary
        medialibrary.observable.addObserver(self)
        fileArrayLock.lock()
        files = medialibrary.genres()
    }

    func append(_ item: VLCMLGenre) {
        defer {
            fileArrayLock.unlock()
        }
        fileArrayLock.lock()
        files.append(item)
    }
}

// MARK: - MediaLibraryObserver

extension GenreModel: MediaLibraryObserver {
    func medialibrary(_ medialibrary: MediaLibraryService, didAddGenres genres: [VLCMLGenre]) {
        genres.forEach({ append($0) })
        observable.notifyObservers {
            $0.mediaLibraryBaseModelReloadView()
        }
    }

    func medialibrary(_ medialibrary: MediaLibraryService,
                      didModifyGenresWithIds genresIds: [NSNumber]) {
        defer {
            fileArrayLock.unlock()
        }
        var genres = [VLCMLGenre]()

        genresIds.forEach() {
            guard let safeGenre = medialibrary.medialib.genre(withIdentifier: $0.int64Value) else {
                return
            }
            genres.append(safeGenre)
        }

        fileArrayLock.lock()
        files = swapModels(with: genres)
        observable.notifyObservers {
            $0.mediaLibraryBaseModelReloadView()
        }
    }

    func medialibrary(_ medialibrary: MediaLibraryService, didDeleteGenresWithIds genresIds: [NSNumber]) {
        defer {
            fileArrayLock.unlock()
        }
        fileArrayLock.lock()
        files.removeAll {
            genresIds.contains(NSNumber(value: $0.identifier()))
        }
        observable.notifyObservers {
            $0.mediaLibraryBaseModelReloadView()
        }
    }

    func medialibraryDidStartRescan() {
        defer {
            fileArrayLock.unlock()
        }
        fileArrayLock.lock()
        files.removeAll()
    }
}

// MARK: - Sort
extension GenreModel {
    func sort(by criteria: VLCMLSortingCriteria, desc: Bool) {
        defer {
            fileArrayLock.unlock()
        }
        fileArrayLock.lock()
        files = medialibrary.genres(sortingCriteria: criteria, desc: desc)
        sortModel.currentSort = criteria
        sortModel.desc = desc
        observable.notifyObservers {
            $0.mediaLibraryBaseModelReloadView()
        }
    }
}

// MARK: - Search
extension VLCMLGenre: SearchableMLModel {
    func contains(_ searchString: String) -> Bool {
        return search(searchString, in: name)
    }
}

// MARK: - Helpers
extension VLCMLGenre {
    @objc func numberOfTracksString() -> String {
        let numberOftracks = numberOfTracks()
        if numberOftracks != 1 {
            return String(format: NSLocalizedString("TRACKS", comment: ""), numberOftracks)
        }
        return String(format: NSLocalizedString("TRACK", comment: ""), numberOftracks)
    }

    func accessibilityText() -> String? {
        return name + " " + numberOfTracksString()
    }
}

extension VLCMLGenre: MediaCollectionModel {
    func sortModel() -> SortModel? {
        return SortModel([.alpha, .album, .duration, .releaseDate])
    }

    func files(with criteria: VLCMLSortingCriteria,
               desc: Bool = false) -> [VLCMLMedia]? {
        return tracks(with: criteria, desc: desc)
    }

    func title() -> String {
        return name
    }
}
