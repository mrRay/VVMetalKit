//
//  SizingTool_objc.h
//  VVMetalKit
//
//  Created by testAdmin on 4/27/21.
//

#ifndef SizingTool_objc_h
#define SizingTool_objc_h


#import <TargetConditionals.h>
#if TARGET_OS_IOS
#include <VVMetalKitTouch/SizingTool_c.h>
#else
#include <VVMetalKit/SizingTool_c.h>
#endif

#include <Foundation/Foundation.h>
#include <CoreGraphics/CoreGraphics.h>
//#import "TargetConditionals.h"








#if !TARGET_OS_IOS
GPoint GPointFromNSPoint(NSPoint inPoint);
#endif
GPoint GPointFromCGPoint(CGPoint inPoint);


#if !TARGET_OS_IOS
GSize GSizeFromNSSize(NSSize inSize);
#endif
GSize GSizeFromCGSize(CGSize inSize);


#if !TARGET_OS_IOS
GRect GRectFromNSRect(NSRect inRect);
#endif
GRect GRectFromCGRect(CGRect inRect);


NSString * NSStringFromGRect(GRect inRect);
NSString * NSStringFromGSize(GSize inSize);
NSString * NSStringFromGPoint(GPoint inPoint);




#endif /* SizingTool_objc_h */
