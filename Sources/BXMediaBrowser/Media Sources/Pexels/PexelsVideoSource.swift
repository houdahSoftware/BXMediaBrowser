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
import SwiftUI


//----------------------------------------------------------------------------------------------------------------------


open class PexelsVideoSource : Source, AccessControl
{
	/// The unique identifier of this source must always remain the same. Do not change this
	/// identifier, even if the class name changes due to refactoring, because the identifier
	/// might be stored in a preferences file or user documents.
	
	static let identifier = "PexelsVideoSource:"
	
	
//----------------------------------------------------------------------------------------------------------------------


	/// Creates a new Source for local file system directories
	
	public init(in library:Library?)
	{
		Pexels.log.verbose {"\(Self.self).\(#function) \(Self.identifier)"}
		let icon = CGImage.image(named:"Pexels", in:.BXMediaBrowser)
		super.init(identifier:Self.identifier, icon:icon, name:"Pexels.com", filter:PexelsFilter(), in:library)
		self.loader = Loader(loadHandler:self.loadContainers)
	}
	
	
//----------------------------------------------------------------------------------------------------------------------


	/// Loads the top-level containers of this source.
	///
	/// Subclasses can override this function, e.g. to load top level folder from the preferences file
	
	private func loadContainers(with sourceState:[String:Any]? = nil, filter:Object.Filter, in library:Library?) async throws -> [Container]
	{
		Pexels.log.debug {"\(Self.self).\(#function) \(identifier)"}

		var containers:[Container] = []
		
		// Add Live Search
		
		guard let filter = filter as? PexelsFilter else { return containers }
		let name = NSLocalizedString("Search", tableName:"Pexels", bundle:.BXMediaBrowser, comment:"Container Name")
		containers += PexelsVideoContainer(identifier:"PexelsVideoSource:Search", icon:"magnifyingglass", name:name, filter:filter, saveHandler:
		{
			[weak self] in self?.saveContainer($0)
		},
		in:library)

		// Add Saved Searches
		
		if let savedFilterDatas = sourceState?[Self.savedFilterDatasKey] as? [Data]
		{
			for filterData in savedFilterDatas
			{
				guard let filter = try? JSONDecoder().decode(PexelsFilter.self, from:filterData) else { continue }
				guard let container = self.createContainer(with:filter) else { continue }
				containers += container
			}
		}
		
		return containers
	}
	
	
	/// Creates a new "saved" copy of the live search container
	
	func saveContainer(_ container:Container)
	{
		Pexels.log.debug {"\(Self.self).\(#function)"}

		guard let liveSearchContainer = container as? PexelsVideoContainer else { return }
		guard let liveFilter = liveSearchContainer.filter as? PexelsFilter else { return }
		guard let savedContainer = self.createContainer(with:liveFilter.copy) else { return }

		// Only add savedContainer if it is unique
		
		Task
		{
			let savedContainers = await self.containers
				.compactMap { $0 as? PexelsContainer }
				.filter { $0.saveHandler == nil }
				
			for container in savedContainers
			{
				if container.identifier == savedContainer.identifier { return }
			}
			
			await MainActor.run
			{
				self.addContainer(savedContainer)
			}
		}
	}


	/// Creates a new "saved" PexelsContainer with the specified filter
	
	func createContainer(with filter:PexelsFilter) -> PexelsVideoContainer?
	{
		guard !filter.searchString.isEmpty else { return nil }

		let searchString = filter.searchString
		let orientation = filter.orientation.rawValue
		let color = filter.color.rawValue
		let identifier = "PexelsVideoSource:\(searchString)/\(orientation)/\(color)".replacingOccurrences(of:" ", with:"-")
		let name = PexelsVideoContainer.description(with:filter)
		
		return PexelsVideoContainer(
			identifier:identifier,
			icon:"rectangle.stack",
			name:name,
			filter:filter,
			removeHandler:
			{
				[weak self] container in
				
				let title = NSLocalizedString("Alert.title.removeFolder", bundle:.BXMediaBrowser, comment:"Alert Title")
				let message = String(format:NSLocalizedString("Alert.message.removeFolder", bundle:.BXMediaBrowser, comment:"Alert Message"), container.name)
				let ok = NSLocalizedString("Remove", bundle:.BXMediaBrowser, comment:"Button Title")
				let cancel = NSLocalizedString("Cancel", bundle:.BXMediaBrowser, comment:"Button Title")
				
				#if os(macOS)
				
				NSAlert.presentModal(style:.critical, title:title, message:message, okButton:ok, cancelButton:cancel)
				{
					[weak self] in self?.removeContainer(container)
				}
				
				#else
				
				#warning("TODO: implement for iOS")
				
				#endif
			},
			in:library)
	}


//----------------------------------------------------------------------------------------------------------------------


	/// Returns the archived filterData of all saved Containers
	
	override public func state() async -> [String:Any]
	{
		var state = await super.state()
		
		let savedFilterDatas = await self.containers
			.compactMap { $0 as? PexelsVideoContainer }
			.filter { $0.saveHandler == nil }
			.compactMap { $0.filterData }

		state[Self.savedFilterDatasKey] = savedFilterDatas

		return state
	}

	internal static var savedFilterDatasKey:String { "savedFilterDatas" }

	/// Saves the properties that are relevant to this Source to the supplied state dictionary
	
	override open func save(to state:inout [String:Any])
	{
		super.save(to:&state)
		
		if let filter = self.filter as? PexelsFilter
		{
			state["orientation"] = filter.orientation.rawValue
			state["color"] = filter.color.rawValue
			state["size"] = filter.size.rawValue
		}
	}
	
	/// Restore the properties relevant to this Source from the supplied Source dictionary
	
	override open func restore(from state:[String:Any]? = nil)
	{
		guard let filter = self.filter as? PexelsFilter else { return }
		guard let state = state else { return }
		
		super.restore(from:state)
		
		if let value = state["orientation"] as? String, let orientation = PexelsFilter.Orientation(rawValue:value)
		{
			filter.orientation = orientation
		}
		
		if let value = state["color"] as? String, let color = PexelsFilter.Color(rawValue:value)
		{
			filter.color = color
		}
		
		if let value = state["size"] as? String, let size = PexelsFilter.Size(rawValue:value)
		{
			filter.size = size
		}
	}
}


//----------------------------------------------------------------------------------------------------------------------
