//----------------------------------------------------------------------------------------------------------------------
//
//  Copyright ©2022 Peter Baumgartner. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//
//----------------------------------------------------------------------------------------------------------------------


import BXSwiftUtils
import Foundation
import ImageIO
#if os(macOS)
import AppKit
#else
import UIKit
#endif


//----------------------------------------------------------------------------------------------------------------------


open class LightroomCCObject : Object
{
	/// Creates a new Object for the file at the specified URL

	public required init(with asset:LightroomCC.Asset)
	{
		super.init(
			identifier: "LightroomCC:Asset:\(asset.id)",
			name: asset.name,
			data: asset,
			loadThumbnailHandler: Self.loadThumbnail,
			loadMetadataHandler: Self.loadMetadata,
			downloadFileHandler: Self.downloadFile)
	}


//----------------------------------------------------------------------------------------------------------------------


	/// Downloads the thumbnail image for the specified Lightroom asset

	open class func loadThumbnail(for identifier:String, data:Any) async throws -> CGImage
	{
		guard let asset = data as? LightroomCC.Asset else { throw Error.loadThumbnailFailed }

		let catalogID = LightroomCC.shared.catalogID
		let assetID = asset.id
		let image = try await LightroomCC.shared.image(from:"https://lr.adobe.io/v2/catalogs/\(catalogID)/assets/\(assetID)/renditions/thumbnail2x")

		return image
	}


//----------------------------------------------------------------------------------------------------------------------


	/// Loads the metadata dictionary for the specified local file URL

	open class func loadMetadata(for identifier:String, data:Any) async throws -> [String:Any]
	{
		LightroomCC.log.verbose {"\(Self.self).\(#function) \(identifier)"}

		guard let asset = data as? LightroomCC.Asset else { throw Error.loadThumbnailFailed }

		var metadata:[String:Any] = [:]

		metadata[.titleKey] = asset.name
		metadata[.widthKey] = asset.width
		metadata[.heightKey] = asset.height
		metadata[.fileSizeKey] = asset.fileSize
		
//		metadata[.descriptionKey] = photo.alt
//		metadata[.authorsKey] = [photo.photographer]
//		metadata[.whereFromsKey] = [photo.url]
//		metadata["photographer"] = photo.photographer
//		metadata["photographer_url"] = photo.photographer_url
//		metadata["url"] = photo.url
//		metadata["photo_src_original"] = photo.src.original

		return metadata
	}


	/// Tranforms the metadata dictionary into an order list of human readable information (with optional click actions)

	@MainActor override open var localizedMetadata:[ObjectMetadataEntry]
    {
		guard let asset = data as? LightroomCC.Asset else { return [] }

		var array:[ObjectMetadataEntry] = []

		let photoLabel = NSLocalizedString("File", tableName:"LightroomCC", bundle:.BXMediaBrowser, comment:"Label")
		array += ObjectMetadataEntry(label:photoLabel, value:asset.name)

		let imageSizeLabel = NSLocalizedString("Image Size", tableName:"LightroomCC", bundle:.BXMediaBrowser, comment:"Label")
		array += ObjectMetadataEntry(label:imageSizeLabel, value:"\(asset.width) × \(asset.height) Pixels")

		let fileSizeLabel = NSLocalizedString("File Size", tableName:"LightroomCC", bundle:.BXMediaBrowser, comment:"Label")
		array += ObjectMetadataEntry(label:fileSizeLabel, value:asset.fileSize.fileSizeDescription)

		return array
    }
    
    
//----------------------------------------------------------------------------------------------------------------------


	// Returns the filename of the file that will be downloaded

	override public var localFileName:String
	{
		Self.localFileName(for:identifier, data:data)
	}

	// LightroomCC always returns JPEG files

	override public var localFileUTI:String
	{
		kUTTypeJPEG as String
	}

	static func localFileName(for identifier:String, data:Any) -> String
	{
		"\(identifier).jpg"
//		(data as? LightroomCC.Asset)?.name ?? ""
	}


	/// Starts downloading an image file

	open class func downloadFile(for identifier:String, data:Any) async throws -> URL
	{
		LightroomCC.log.debug {"\(Self.self).\(#function) \(identifier)"}

		guard let asset = data as? LightroomCC.Asset else { throw Error.downloadFileFailed }
		
		// Download the file

		let catalogID = LightroomCC.shared.catalogID
		let assetID = asset.id
		let request = try LightroomCC.shared.request(for:"https://lr.adobe.io/v2/catalogs/\(catalogID)/assets/\(assetID)/renditions/2048")
		let tmpURL = try await URLSession.shared.downloadFile(with:request)

		// Rename the file

		let folderURL = tmpURL.deletingLastPathComponent()
		let filename = self.localFileName(for:identifier, data:data)
		let localURL = folderURL.appendingPathComponent(filename)
		try FileManager.default.moveItem(at:tmpURL, to:localURL)

		// Register in TempFilePool

		TempFilePool.shared.register(localURL)
		return localURL
	}


//----------------------------------------------------------------------------------------------------------------------


	/// QuickLook support
	
	override public var previewItemURL:URL!
    {
		guard let asset = data as? LightroomCC.Asset else { return nil }
		let catalogID = LightroomCC.shared.catalogID
		let assetID = asset.id
		return URL(string:"https://lr.adobe.io/v2/catalogs/\(catalogID)/assets/\(assetID)/renditions/1280")
    }

	override open var previewItemTitle: String!
    {
		self.localFileName
    }
}


//----------------------------------------------------------------------------------------------------------------------
