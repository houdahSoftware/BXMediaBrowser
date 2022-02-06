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

import AppKit


//----------------------------------------------------------------------------------------------------------------------


public class ImageObjectViewController : ObjectViewController
{
    override class var identifier:NSUserInterfaceItemIdentifier
    {
    	NSUserInterfaceItemIdentifier("BXMediaBrowser.ImageObjectViewController")
	}
	
	override class var width:CGFloat { 120 }
	
	override class var height:CGFloat { 96 }
	
	override class var spacing:CGFloat { 10 }


//----------------------------------------------------------------------------------------------------------------------


	/// Redraws the cell by updating the thumbnail and name
	
	override public func redraw()
	{
		guard let object = object else { return }

		if let thumbnail = object.thumbnailImage
		{
			let w = thumbnail.width
			let h = thumbnail.height
			let size = CGSize(width:w, height:h)
			self.imageView?.image = NSImage(cgImage:thumbnail, size:size)
			self.imageView?.imageScaling = .scaleProportionallyUpOrDown
		}
	
		self.textField?.stringValue = object.name
	}
	
	
//----------------------------------------------------------------------------------------------------------------------


	// MARK: -
	
    override public var isSelected:Bool
    {
        didSet { self.updateHighlight() }
    }

	override public var highlightState:NSCollectionViewItem.HighlightState
    {
        didSet { self.updateHighlight() }
    }

    private func updateHighlight()
    {
        guard isViewLoaded else { return }

		let isHilited = self.isSelected	|| self.highlightState != .none

		if let layer = self.imageView?.subviews.first?.layer
		{
			layer.borderWidth = isHilited ? 4.0 : 0.0
			layer.borderColor = isHilited ? NSColor.systemYellow.cgColor : NSColor.clear.cgColor
		}
    }
}


//----------------------------------------------------------------------------------------------------------------------


// We do not want cell selection or drag & drop to work when clicking on the transparent cell background.
// Only the visible part of the thumbnail, should be the active area. For this reason we need to override
// hit-testing for the root view of the cell.

// Inspired by https://developer.apple.com/forums/thread/30023 and
// https://stackoverflow.com/questions/48765128/drag-selecting-in-nscollectionview-from-inside-of-items

class ImageThumbnailView : ObjectView
{
	override func hitTest(_ point:NSPoint) -> NSView?
	{
		let view = super.hitTest(point)
		
		// The NSImageView spans the entire area of the cell, but the thumbnail itself does not (due to different
		// aspect ratio it is fitted inside) so check the first subview of NSImageView (which displays the image
		// itself). Hopefully this woon't break in future OS releases.
		
		if let imageView = view as? NSImageView, let thumbnail = imageView.subviews.first
		{
			let p = thumbnail.convert(point, from:self.superview)
			if !NSPointInRect(p,thumbnail.bounds) { return nil }
		}
		
		// Exclude the textfield from hit testing
		
		if view is NSTextField
		{
			return nil
		}
		
		return view
	}
}


//----------------------------------------------------------------------------------------------------------------------


#endif