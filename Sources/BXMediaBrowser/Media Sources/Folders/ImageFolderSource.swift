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
import BXSwiftUI
import Foundation
import QuartzCore


//----------------------------------------------------------------------------------------------------------------------


open class ImageFolderSource : FolderSource
{
	/// Creates a Container for the folder at the specified URL
	
	override open func createContainer(for url:URL) throws -> Container?
	{
		let container = ImageFolderContainer(url:url)
		{
			[weak self] in self?.removeContainer($0)
		}
		
		return container
	}
}


//----------------------------------------------------------------------------------------------------------------------


// MARK: -

open class ImageFolderContainer : FolderContainer
{
	override open class func createObject(for url:URL) throws -> Object?
	{
		guard url.exists else { throw Object.Error.notFound }
		guard url.isImageFile else { return nil }
		return ImageFile(url:url)
	}

    @MainActor override var localizedObjectCount:String
    {
		let n = self.objects.count
		let str = n.localizedImagesString
		return str
    }
}


//----------------------------------------------------------------------------------------------------------------------


// MARK: -

open class ImageFile : FolderObject
{
	/// Creates a thumbnail image for the specified local file URL
	
	override open class func loadThumbnail(for identifier:String, data:Any) async throws -> CGImage
	{
		FolderSource.log.verbose {"\(Self.self).\(#function) \(identifier)"}

		guard let url = data as? URL else { throw Error.loadThumbnailFailed }
		guard url.exists else { throw Error.loadThumbnailFailed }

		let options:[CFString:AnyObject] =
		[
			kCGImageSourceCreateThumbnailFromImageIfAbsent : kCFBooleanTrue,
			kCGImageSourceCreateThumbnailFromImageAlways : kCFBooleanFalse,
			kCGImageSourceThumbnailMaxPixelSize : NSNumber(value:256.0),
			kCGImageSourceCreateThumbnailWithTransform : kCFBooleanTrue
		]

		guard let source = CGImageSourceCreateWithURL(url as CFURL,nil) else { throw Error.loadThumbnailFailed }
		guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source,0,options as CFDictionary) else { throw Error.loadThumbnailFailed }
		return thumbnail
	}


	/// Loads the metadata dictionary for the specified local file URL
	
	override open class func loadMetadata(for identifier:String, data:Any) async throws -> [String:Any]
	{
		FolderSource.log.verbose {"\(Self.self).\(#function) \(identifier)"}

		guard let url = data as? URL else { throw Error.loadMetadataFailed }
		guard url.exists else { throw Error.loadMetadataFailed }
		
		var metadata = try await super.loadMetadata(for:identifier, data:data)
		
		if let source = CGImageSourceCreateWithURL(url as CFURL,nil),
		   let properties = CGImageSourceCopyPropertiesAtIndex(source,0,nil),
		   let dict = properties as? [String:Any]
		{
			for (key,value) in dict
			{
				metadata[key] = value
			}
		}
		
		return metadata
	}

	
	/// Returns the UTI of the promised image file 
	
	override var localFileUTI:String
	{
		guard let url = data as? URL else { return String.imageUTI }
		return url.uti ?? String.imageUTI
	}


	/// Tranforms the metadata dictionary into an order list of human readable information (with optional click actions)
	
	@MainActor override var localizedMetadata:[ObjectMetadataEntry]
    {
		guard let url = data as? URL else { return [] }
		let metadata = self.metadata ?? [:]
		let exif = metadata["{Exif}"] as? [String:Any] ?? [:]
		var array:[ObjectMetadataEntry] = []
		
		array += ObjectMetadataEntry(label:"File", value:"\(self.name)", action:url.reveal)

		if let w = metadata["PixelWidth"] as? Int, let h = metadata["PixelHeight"] as? Int
		{
			array += ObjectMetadataEntry(label:"Image Size", value:"\(w) × \(h) Pixels")
		}
		
		if let value = metadata["fileSize"] as? Int, let str = Formatter.fileSizeFormatter.string(for:value)
		{
			array += ObjectMetadataEntry(label:"File Size", value:str) // value.fileSizeDescription)
		}
	
		if let value = exif["ApertureValue"] as? Double, let str = Formatter.singleDigitFormatter.string(for:value)
		{
			array += ObjectMetadataEntry(label:"Aperture", value:"f\(str)")
		}
	
		if let value = exif["ExposureTime"] as? Double, let str = Formatter.exposureTimeFormatter.string(for:value)
		{
			array += ObjectMetadataEntry(label:"Exposure Time", value:str)
		}
	
		if let value = exif["FocalLenIn35mmFilm"] as? Int
		{
			array += ObjectMetadataEntry(label:"Focal Length", value:"\(value)mm")
		}
		
		if let value = metadata["ProfileName"] as? String
		{
			array += ObjectMetadataEntry(label:"Color Space", value:value)
		}

		if let value = exif["DateTimeOriginal"] as? String, let date = value.date
		{
			array += ObjectMetadataEntry(label:"Capture Date", value:String(with:date))
		}
		else if let value = metadata["creationDate"] as? Date
		{
			array += ObjectMetadataEntry(label:"Creation Date", value:String(with:value))
		}
		
		return array
    }


}


//----------------------------------------------------------------------------------------------------------------------

