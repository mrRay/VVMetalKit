//
//  SizingTool_objc.h
//  VVMetalKit
//
//  Created by testAdmin on 4/27/21.
//

#ifndef SizingTool_objc_h
#define SizingTool_objc_h


#include <VVMetalKit/SizingTool_c.h>

#include <Foundation/Foundation.h>
#include <CoreGraphics/CoreGraphics.h>








GPoint GPointFromNSPoint(NSPoint inPoint);
GPoint GPointFromCGPoint(CGPoint inPoint);


GSize GSizeFromNSSize(NSSize inSize);
GSize GSizeFromCGSize(CGSize inSize);


GRect GRectFromCGRect(CGRect inRect);
GRect GRectFromNSRect(NSRect inRect);


NSString * NSStringFromGRect(GRect inRect);
NSString * NSStringFromGSize(GSize inSize);
NSString * NSStringFromGPoint(GPoint inPoint);




#endif /* SizingTool_objc_h */
