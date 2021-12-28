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


import Combine
import Foundation


//----------------------------------------------------------------------------------------------------------------------


extension Library
{
	class StateSaver
	{
		public var action:(()->Void)? = nil
		
		@Published internal var requestCounter = 0
	
		private var observers:[Any] = []
		
		init()
		{
			self.observers += self.$requestCounter
				.debounce(for:0.1, scheduler:RunLoop.main)
				.sink
				{
					[weak self] _ in self?.action?()
				}
		}
		
		func request()
		{
			self.requestCounter += 1
		}
	}


//----------------------------------------------------------------------------------------------------------------------


	/// Calling this function causes the state of this Library to be saved to persistent storage. Please note
	/// that multiple consecutive calls of this function will be coalesced (debounced) so that the heavy duty
	/// work is only performed once (per debounce interval).
	
	public func saveState()
	{
		self.stateSaver.request()
	}
	
	
	// Since getting the state is an async function that accesses @MainActor properties, this work has to be
	// wrapped in a Task.
	
	internal func asyncSaveState()
	{
		Task
		{
			Swift.print("\(Self.self).\(#function)")
			let state = await self.state()
			self.saveState(state)
		}
	}
	
	/// Recursively walks through the data model tree and gathers the current state info. Since this
	/// operation is accessing async properties, this function is also async and can only be called
	/// from a Task or another async function.
	
	public func state() async -> [String:Any]
	{
		var state:[String:Any] = [:]
		
		for section in self.sections
		{
			let key = section.stateKey
			let value = await section.state()
			state[key] = value
		}
		
		state[selectedContainerIdentifierKey] = self.selectedContainer?.identifier
		
		return state
	}


	/// This key can be used to safely access info in dictionaries or UserDefaults
	
	public var stateKey:String
	{
		"BXMediaBrowser.Library.\(identifier)".replacingOccurrences(of:".", with:"-")
	}

	public var selectedContainerIdentifierKey:String
	{
		"selectedContainerIdentifier"
	}
}


//----------------------------------------------------------------------------------------------------------------------
