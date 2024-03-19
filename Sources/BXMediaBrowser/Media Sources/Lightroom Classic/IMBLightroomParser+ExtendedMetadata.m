//
//  IMBLightroomParser+ExtendedMetadata.m
//  BXMediaBrowser
//
//  Created by Pierre Bernard on 17.03.24.
//

#import "IMBLightroomParser+ExtendedMetadata.h"

#import <iMedia/FMDatabase.h>
#import <iMedia/FMResultSet.h>


@implementation IMBLightroomParser (ExtendedMetadata)

- (NSString *)xmpStringForObject:(IMBObject *)inObject
{
	if (! [inObject isKindOfClass:[IMBLightroomObject class]]) {
		return nil;
	}

	__block NSString	*xmpStringForObject		= nil;

	IMBLightroomObject	*lightroomObject		= (IMBLightroomObject *)inObject;

	[self inLibraryDatabase:^(FMDatabase *libraryDatabase) {
		if (libraryDatabase == nil) {
			return;
		}

		NSNumber *idLocal = lightroomObject.idLocal;

		if (idLocal == nil) {
			return;
		}

		NSString *query = [self xmpStringQuery];

		FMResultSet *resultSet = [libraryDatabase executeQuery:query, idLocal];
		NSString *xmpString = nil;

		if ([resultSet next]) {
			xmpString = [resultSet stringForColumn:@"xmp"];

			if ([xmpString length] == 0) {
				NSData *xmpData = [resultSet dataForColumn:@"xmp"];
				NSUInteger dataLength = [xmpData length];
				NSUInteger headerLength = 4;

				if (dataLength > headerLength) {
					int32_t decodedLength;

					[xmpData getBytes:&decodedLength length:4];

					decodedLength = CFSwapInt32BigToHost(decodedLength);

					NSData *zLibData = [xmpData subdataWithRange:NSMakeRange(headerLength + 2, dataLength - headerLength - 2)];
					NSError *zLibError = nil;
					NSData *zlibInflatedData = [zLibData decompressedDataUsingAlgorithm:NSDataCompressionAlgorithmZlib error:&zLibError];

					if ([zlibInflatedData length] == decodedLength) {
						xmpString = [[NSString alloc] initWithData:zlibInflatedData encoding:NSUTF8StringEncoding];
					}
					else if (zlibInflatedData == nil) {
						NSLog(@"Failed to decompress XMP data. Error: %@", zLibError);
					}
					else {
						NSLog(@"Unexepected XMP data length: %lu expected %d", (unsigned long)[zlibInflatedData length], decodedLength);
					}
				}
			}

			if ([xmpString length] == 0) {
				NSLog(@"No xmp data for image with id %@", idLocal);

				xmpString = nil;
			}
		}
		else {
			NSLog(@"Found no image with id %@", idLocal);
		}

		if ([resultSet next]) {
			NSLog(@"Found more than one image with id %@", idLocal);

			xmpString = nil;
		}

		[resultSet close];

		xmpStringForObject = xmpString;
	}];

	return xmpStringForObject;
}

- (NSString *)xmpStringQuery
{
	NSString *query =
	@" SELECT am.xmp"
	@" FROM Adobe_AdditionalMetadata am"
	@" WHERE am.image = ?;";

	return query;
}

@end
