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


import SwiftUI


//----------------------------------------------------------------------------------------------------------------------


open class LightroomCCFilter : Object.Filter, Equatable
{
	public static func == (lhs:LightroomCCFilter, rhs:LightroomCCFilter) -> Bool
	{
		lhs.searchString == rhs.searchString &&
		lhs.rating == rhs.rating &&
		lhs.sortType == rhs.sortType &&
		lhs.sortDirection == rhs.sortDirection
	}
	
	
	override open var objectComparator : ObjectComparator?
	{
		/*if sortType == .alphabetical
		{
			let comparator = Self.compareAlphabetical
			if sortDirection == .ascending { return comparator }
			return { !comparator($0,$1) }
		}
		else if sortType == .creationDate
		{
			let comparator = Self.compareCreationDate
			if sortDirection == .ascending { return comparator }
			return { !comparator($0,$1) }
		}
		else*/ if sortType == .rating
		{
			let comparator = Self.compareRating
			if sortDirection == .ascending { return comparator }
			return { !comparator($0,$1) }
		}
		
		return nil
	}

	/// Sorts Objects alphabetically by filename like the Finder
	
//	public static func compareAlphabetical(_ object1:Object,_ object2:Object) -> Bool
//	{
//		let name1 = object1.name as NSString
//		let name2 = object2.name
//		return name1.localizedStandardCompare(name2) == .orderedAscending
//	}
//
//	/// Sorts Objects by creationDate
//
//	public static func compareCreationDate(_ object1:Object,_ object2:Object) -> Bool
//	{
//		guard let url1 = object1.data as? URL else { return false }
//		guard let url2 = object2.data as? URL else { return false }
//		guard let date1 = url1.creationDate else { return false }
//		guard let date2 = url2.creationDate else { return false }
//		return date1 < date2
//	}
}


//----------------------------------------------------------------------------------------------------------------------


//extension Object.Filter.SortType
//{
//	public static let alphabetical = "alphabetical"
//	public static let creationDate = "creationDate"
//}


//----------------------------------------------------------------------------------------------------------------------