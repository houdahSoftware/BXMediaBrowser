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


#if os(macOS)

import BXSwiftUtils
import BXSwiftUI
import AppKit


//----------------------------------------------------------------------------------------------------------------------


public class FileDropDestination : NSObject, NSDraggingDestination
{
	/// Dropped files will be copied to this destination folder
	
	private var folderURL:URL
	
	/// If set this handler will be called at appropriate times to highlight or unhighlight the drop destination
	/// view, as the mouse moves in and out
	
	public var highlightDropTargetHandler:((Bool)->Void)? = nil
    
    /// A background queue for file downloading/copying
	
	private let queue:OperationQueue =
	{
		let providerQueue = OperationQueue()
		providerQueue.qualityOfService = .userInitiated
		return providerQueue
	}()
    
    /// The Progress object for the current download/copy operation
	
    public private(set) var progress:Progress? = nil
    
    /// The start time of a download/copy operation
	
    private var startTime:CFAbsoluteTime = .zero
    
    /// KVO observers
	
	private var observers:[Any] = []
	
	
//----------------------------------------------------------------------------------------------------------------------


	/// Creates a new FileDropDestination
	
	public init(folderURL:URL)
	{
		self.folderURL = folderURL
	}


	/// Call this helper in the setup code of your view to configure it for receiving file drops
	
	public class func registerDragTypes(for view:NSView)
	{
        view.registerForDraggedTypes(NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) })
        view.registerForDraggedTypes([NSPasteboard.PasteboardType.fileURL])
	}
	
	
//----------------------------------------------------------------------------------------------------------------------


	// MARK: - NSDraggingDestination
	
	
	public func draggingEntered(_ sender:NSDraggingInfo) -> NSDragOperation
    {
 		self.highlightDropTargetHandler?(true)
		return .copy
    }

    public func draggingExited(_ sender:NSDraggingInfo?)
    {
 		self.highlightDropTargetHandler?(false)
    }

	public func performDragOperation(_ sender:NSDraggingInfo) -> Bool
	{
		self.copyDroppedFiles(sender)
        return true
	}

	public func concludeDragOperation(_ sender: NSDraggingInfo?)
    {
 		self.highlightDropTargetHandler?(false)
    }


//----------------------------------------------------------------------------------------------------------------------


	// MARK: - NSCollectionViewDelegate
	
	@MainActor public func collectionView(_ collectionView:NSCollectionView, validateDrop draggingInfo:NSDraggingInfo, proposedIndexPath:AutoreleasingUnsafeMutablePointer<NSIndexPath>, dropOperation:UnsafeMutablePointer<NSCollectionView.DropOperation>) -> NSDragOperation
	{
		let n = collectionView.numberOfItems(inSection:0)
        dropOperation.pointee = .before
        proposedIndexPath.pointee = NSIndexPath(index:n)
		return [.copy]
	}


	@MainActor public func collectionView(_ collectionView:NSCollectionView, acceptDrop draggingInfo:NSDraggingInfo, indexPath:IndexPath, dropOperation:NSCollectionView.DropOperation) -> Bool
	{
		self.copyDroppedFiles(draggingInfo)
		return true
	}


//----------------------------------------------------------------------------------------------------------------------


	// MARK: - Copying
	
	
	/// Copies dropped files to the destination folder. In the case of NSFilePromiseProvider, the file may
	/// have to be downloaded first.
	
	private func copyDroppedFiles(_ draggingInfo:NSDraggingInfo)
	{
		// Get the dropped files from the dragging pasteboard
		
		let classes = [ NSFilePromiseReceiver.self, NSURL.self ]
        let options:[NSPasteboard.ReadingOptionKey:Any] = [ .urlReadingFileURLsOnly:true ]
		let files = draggingInfo.draggingPasteboard.readObjects(forClasses:classes, options:options) ?? []
		
		// Prepare progress observing
		
		let progress = self.prepareProgress(with:files.count)
		
		// Iterate through all NSDraggingItems and copy dropped files
		
		for file in files
		{
			progress.becomeCurrent(withPendingUnitCount:1)
			
			if let receiver = file as? NSFilePromiseReceiver
			{
				self.copyFile(with:receiver)
			}
			else if let srcURL = file as? URL
			{
				self.copyFile(at:srcURL)
			}
			
			progress.resignCurrent()
		}
	}


	/// Downloads a promised file and copies it to the destination folder
	
	private func copyFile(with receiver:NSFilePromiseReceiver)
	{
		receiver.receivePromisedFiles(atDestination:self.folderURL, options:[:], operationQueue:self.queue)
		{
			url,error in
			
			if let error = error
			{
				logDragAndDrop.error {"\(Self.self).\(#function) ERROR \(error)"}
			}
			else
			{
				logDragAndDrop.debug {"\(Self.self).\(#function) RECEIVED \(url)"}
			}
		}
	}
	
	
	/// Copies the specified file to the destination folder
	
	private func copyFile(at srcURL:URL)
	{
		// Unfortunately FileManager doesn't support NSProgress, so we have to fake it here
		
		let childProgress = Progress(totalUnitCount:1)
		Progress.globalParent?.addChild(childProgress, withPendingUnitCount:1)
		defer { childProgress.completedUnitCount = 1 }
		
		// Link or copy the file to the folder
		
		let dstURL = self.folderURL.appendingPathComponent(srcURL.lastPathComponent)
		
		do
		{
			try FileManager.default.linkItem(at:srcURL, to:dstURL)
		}
		catch
		{
			do
			{
				try FileManager.default.copyItem(at:srcURL, to:dstURL)
			}
			catch
			{
				logDragAndDrop.error {"\(Self.self).\(#function) ERROR \(error)"}
			}
		}
	}
	
	
//----------------------------------------------------------------------------------------------------------------------


	// MARK: - Progress
	
	
	/// Creates a root Progress object with the specified totalUnitCount
	
	private func prepareProgress(with count:Int) -> Progress
	{
		// Create root Progress
		
		let progress = Progress(totalUnitCount:Int64(count))
		progress.cancellationHandler = { [weak self] in self?.cancel() }
		self.progress = progress
		Progress.globalParent = progress

		// Store starting time
		
		self.startTime = CFAbsoluteTimeGetCurrent()
		
		// Register KVO observers
		
		self.observers = []
		
		self.observers += KVO(object:progress, keyPath:"fractionCompleted", options:[.new])
		{
			[weak self] _,_ in
			guard let self = self else { return }
			let fraction = progress.fractionCompleted
			self.updateProgress(fraction)
			if fraction >= 0.99 { self.hideProgress() }
		}
		
		BXProgressWindowController.shared.cancelHandler =
		{
			[weak self] in
			self?.cancel()
			self?.hideProgress()
		}

		return progress
	}
	
	
	/// Update the progress UI with the specified fraction
	
	private func updateProgress(_ fraction:Double)
	{
		DispatchQueue.main.async
		{
			let now = CFAbsoluteTimeGetCurrent()
			let dt = now - self.startTime
			let percent = Int(fraction*100)

			BXProgressWindowController.shared.title = "Copying Media Files"
			BXProgressWindowController.shared.value = fraction
			
			if !BXProgressWindowController.shared.isVisible && dt>1.0 && fraction<0.8
			{
				BXProgressWindowController.shared.show()
			}

			logDragAndDrop.verbose {"\(Self.self).\(#function)   progress = \(percent)%   duration = \(dt)s"}
		}
	}
	
	
	/// Hides the progress UI
	
	private func hideProgress()
	{
		DispatchQueue.main.async
		{
			logDragAndDrop.debug {"\(Self.self).\(#function)"}
			
			BXProgressWindowController.shared.hide()
		
			Progress.globalParent = nil
			self.progress = nil
			self.observers = []
		}
	}


	/// Cancels the currently running download/copy operation
	
	public func cancel()
	{
		logDragAndDrop.debug {"\(Self.self).\(#function)"}
		self.progress?.cancel()
	}
}


//----------------------------------------------------------------------------------------------------------------------


#endif
