//
//  Photos-BXPrivate.h
//  BXMediaBrowser
//
//  Created by Pierre Bernard on 08.04.24.
//

#ifndef Photos_BXPrivate_h
#define Photos_BXPrivate_h

#import <Photos/Photos.h>
#import <PhotosUI/PhotosUI.h>


@interface PHAsset (BXPrivate)

- (void)fetchPropertySetsIfNeeded;

@property(readonly, nonatomic) NSString *title;
@property(readonly, nonatomic) NSString *originalFilename;

@end


@interface PHFetchOptions (BXPrivate)

@property(nonatomic) BOOL includeUserSmartAlbums;

@end


@interface PHCollectionList (BXPrivate)

+ (PHFetchResult<PHCollectionList *> *)fetchRootAlbumCollectionListWithOptions:(PHFetchOptions *)options;

@end

#endif /* Photos_BXPrivate_h */
