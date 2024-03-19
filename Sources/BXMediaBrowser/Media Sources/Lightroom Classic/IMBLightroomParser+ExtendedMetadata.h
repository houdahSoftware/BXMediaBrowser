//
//  IMBLightroomParser+ExtendedMetadata.h
//  BXMediaBrowser
//
//  Created by Pierre Bernard on 17.03.24.
//

#import <iMedia/iMedia.h>
#import <iMedia/IMBLightroomParser.h>


@interface IMBLightroomParser (ExtendedMetadata)

- (NSString *)xmpStringForObject:(IMBObject *)inObject;

@end

