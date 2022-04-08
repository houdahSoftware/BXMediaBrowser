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


import Photos
import QuickLookUI


//----------------------------------------------------------------------------------------------------------------------


public class PhotosObject : Object
{
	public init(with asset:PHAsset)
	{
		super.init(
			identifier: Self.identifier(for:asset),
			name: "", // asset.originalFilename ?? "", 	// Getting originalFilename is way too expensive at this point!
			data: asset,
			loadThumbnailHandler: Self.loadThumbnail,
			loadMetadataHandler: Self.loadMetadata,
			downloadFileHandler: Self.downloadFile)
	}

	class func identifier(for asset:PHAsset) -> String
	{
		"Photos:Asset:\(asset.localIdentifier)"
	}
	
	
//----------------------------------------------------------------------------------------------------------------------


//----------------------------------------------------------------------------------------------------------------------


	// MARK: - Thumbnails
	
	/// Creates a thumbnail image for the PHAsset with the specified identifier
	
	class func loadThumbnail(for identifier:String, data:Any) async throws -> CGImage
	{
		Photos.log.verbose {"\(Self.self).\(#function) \(identifier)"}

        return try await withCheckedThrowingContinuation
        {
			continuation in

			guard let asset = data as? PHAsset else
			{
				return continuation.resume(throwing:Object.Error.notFound)
			}
		
			PhotosSource.imageManager.requestImage(for:asset, targetSize:self.thumbnailSize, contentMode:.aspectFit, options:Self.thumbnailOptions)
			{
				image,_ in
				
				if let image = image, let thumbnail = image.cgImage(forProposedRect:nil, context:nil, hints:nil)
				{
					continuation.resume(returning:thumbnail)
				}
				else
				{
					continuation.resume(throwing:Object.Error.loadThumbnailFailed)
				}
			}
		}
	}


	private static var thumbnailOptions:PHImageRequestOptions =
	{
		let options = PHImageRequestOptions()
		options.isNetworkAccessAllowed = true
		options.isSynchronous = true
		options.resizeMode = .fast
		return options
	}()


	private static let thumbnailSize = CGSize(width:256, height:256)


//----------------------------------------------------------------------------------------------------------------------


	// MARK: - Metadata
	
	/// Loads the metadata dictionary for the specified local file URL
	
	class func loadMetadata(for identifier:String, data:Any) async throws -> [String:Any]
	{
		guard let asset = data as? PHAsset else { throw Object.Error.loadMetadataFailed }
		
		Photos.log.verbose {"\(Self.self).\(#function) \(identifier)"}

		var metadata:[String:Any] = [:]
		metadata["mediaType"] = asset.mediaType.rawValue
		metadata[.titleKey] = asset.originalFilename
		metadata[.widthKey] = asset.pixelWidth
		metadata[.heightKey] = asset.pixelHeight
		metadata[.durationKey] = asset.duration
		metadata[.creationDate] = asset.creationDate
		metadata[.modificationDateKey] = asset.modificationDate
//		asset.location

		return metadata
	}


	@MainActor override open var localizedMetadata:[ObjectMetadataEntry]
    {
		return []
    }

//					if let w = metadata["PixelWidth"] as? Int, let h = metadata["PixelHeight"] as? Int
//					{
//						Text("Size: \(w) x \(h) pixels")
//							.lineLimit(1)
//							.opacity(0.5)
//					}
//
//					if let model = metadata["ColorModel"] as? String
//					{
//						Text("Type: \(model)")
//							.lineLimit(1)
//							.opacity(0.5)
//					}
//					if let profile = metadata["ProfileName"] as? String
//					{
//						Text("Colorspace: \(profile)")
//							.lineLimit(1)
//							.opacity(0.5)
//					}


//----------------------------------------------------------------------------------------------------------------------


	// MARK: - Download
	
	// To be overridden in subclasses
	
	class func downloadFile(for identifier:String, data:Any) async throws -> URL
	{
		throw Object.Error.downloadFileFailed
	}
	
	
//----------------------------------------------------------------------------------------------------------------------


	// MARK: - QuickLook
	
	/// Returns the filename of the local preview file
	
	public var previewFilename:String
    {
		(data as? PHAsset)?.originalFilename ?? ""
	}
	
	/// Returns the title for the QuickLook panel
	
	override open var previewItemTitle: String!
    {
		self.localFileName
    }
	
	/// Returns the local file URL to the preview file. If not available yet, it will be downloaded from
	/// the Lightroom server.
	
	override public var previewItemURL:URL!
    {
		if self._previewItemURL == nil && !isDownloadingPreview
		{
			self.isDownloadingPreview = true
			
			Task
			{
				// Download the file (hires)
				
				let url = try await Self.downloadFile(for:identifier, data:data)
				
				// Store it in the TempFilePool and update the QLPreviewPanel
				
				await MainActor.run
				{
					self._previewItemURL = url
					self.isDownloadingPreview = false
					
					QLPreviewPanel.shared().refreshCurrentPreviewItem()
					QLPreviewPanel.shared().reloadData()
				}
			}
 		}
 		
 		return self._previewItemURL
	}

	private var _previewItemURL:URL? = nil
	private var isDownloadingPreview = false
}


//----------------------------------------------------------------------------------------------------------------------


