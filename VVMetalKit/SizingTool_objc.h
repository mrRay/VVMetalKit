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
//#import "TargetConditionals.h"








static inline GPoint GPointFromNSPoint(NSPoint inPoint);
static inline NSPoint NSPointFromGPoint(GPoint inPoint);

static inline GPoint GPointFromCGPoint(CGPoint inPoint);
static inline CGPoint CGPointFromGPoint(GPoint inPoint);


static inline GSize GSizeFromNSSize(NSSize inSize);
static inline NSSize NSSizeFromGSize(GSize inSize);

static inline GSize GSizeFromCGSize(CGSize inSize);
static inline CGPoint CGSizeFromGSize(GSize inSize);


static inline GRect GRectFromNSRect(NSRect inRect);
static inline NSRect NSRectFromGRect(GRect inRect);

static inline GRect GRectFromCGRect(CGRect inRect);
static inline CGRect CGRectFromGRect(GRect inRect);


static inline NSString * NSStringFromGRect(GRect inRect);
static inline NSString * NSStringFromGSize(GSize inSize);
static inline NSString * NSStringFromGPoint(GPoint inPoint);


static inline NSRect NSRectThatFitsRectInRect(NSRect inSrcRect, NSRect inDstRect, SizingMode mode);


static inline NSAffineTransform * TransformThatFitsRectInRect(NSRect inSrcRect, NSRect inDstRect, SizingMode mode);
static inline NSAffineTransform * InverseTransformThatFitsRectInRect(NSRect inSrcRect, NSRect inDstRect, SizingMode mode);


static inline NSString * NSStringFromSizingMode(SizingMode inMode);
static inline SizingMode SizingModeFromNSString(NSString *inString);








static inline GPoint GPointFromNSPoint(NSPoint inPoint)	{
	struct GPoint		returnMe = { (float)inPoint.x, (float)inPoint.y };
	return returnMe;
}
static inline NSPoint NSPointFromGPoint(GPoint inPoint)	{
	return NSMakePoint(inPoint.x, inPoint.y);
}

static inline GPoint GPointFromCGPoint(CGPoint inPoint)	{
	struct GPoint		returnMe = { (float)inPoint.x, (float)inPoint.y };
	return returnMe;
}
static inline CGPoint CGPointFromGPoint(GPoint inPoint)	{
	return CGPointMake(inPoint.x, inPoint.y);
}




static inline GSize GSizeFromNSSize(NSSize inSize)	{
	struct GSize		returnMe = { (float)inSize.width, (float)inSize.height };
	return returnMe;
}
static inline NSSize NSSizeFromGSize(GSize inSize)	{
	return NSMakeSize(inSize.width, inSize.height);
}

static inline GSize GSizeFromCGSize(CGSize inSize)	{
	struct GSize		returnMe = { (float)inSize.width, (float)inSize.height };
	return returnMe;
}
static inline CGPoint CGSizeFromGSize(GSize inSize)	{
	return CGPointMake(inSize.width, inSize.height);
}




static inline GRect GRectFromNSRect(NSRect inRect)	{
	struct GRect		returnMe = { { (float)inRect.origin.x, (float)inRect.origin.y }, { (float)inRect.size.width, (float)inRect.size.height } };
	return returnMe;
}
static inline NSRect NSRectFromGRect(GRect inRect)	{
	return NSMakeRect(inRect.origin.x, inRect.origin.y, inRect.size.width, inRect.size.height);
}

static inline GRect GRectFromCGRect(CGRect inRect)	{
	struct GRect		returnMe = { { (float)inRect.origin.x, (float)inRect.origin.y }, { (float)inRect.size.width, (float)inRect.size.height } };
	return returnMe;
}
static inline CGRect CGRectFromGRect(GRect inRect)	{
	return CGRectMake(inRect.origin.x, inRect.origin.y, inRect.size.width, inRect.size.height);
}




static inline NSString * NSStringFromGRect(GRect inRect)	{
	return [NSString stringWithFormat:@"<GRect %@ %@>",NSStringFromGPoint(inRect.origin),NSStringFromGSize(inRect.size)];
}
static inline NSString * NSStringFromGSize(GSize inSize)	{
	return [NSString stringWithFormat:@"<GSize %0.2f x%0.2f>",inSize.width,inSize.height];
}
static inline NSString * NSStringFromGPoint(GPoint inPoint)	{
	return [NSString stringWithFormat:@"<GPoint %0.2f, %0.2f>",inPoint.x,inPoint.y];
}




static inline NSRect NSRectThatFitsRectInRect(NSRect inSrcRect, NSRect inDstRect, SizingMode mode)	{
	GRect		srcRect = GRectFromNSRect(inSrcRect);
	GRect		dstRect = GRectFromNSRect(inDstRect);
	GRect		returnMe = RectThatFitsRectInRect(srcRect, dstRect, mode);
	return NSRectFromGRect(returnMe);
}




static inline NSAffineTransform * TransformThatFitsRectInRect(NSRect a, NSRect b, SizingMode m)	{
	NSRect				r = NSRectThatFitsRectInRect(a, b, m);
	NSAffineTransform	*returnMe = [NSAffineTransform transform];
	NSAffineTransform	*tmp = nil;
	
	tmp = [NSAffineTransform transform];
	[tmp translateXBy:-1*a.origin.x yBy:-1*a.origin.y];
	[returnMe appendTransform:tmp];
	
	tmp = [NSAffineTransform transform];
	[tmp scaleXBy:r.size.width/a.size.width yBy:r.size.height/a.size.height];
	[returnMe appendTransform:tmp];
	
	tmp = [NSAffineTransform transform];
	[tmp translateXBy:r.origin.x yBy:r.origin.y];
	[returnMe appendTransform:tmp];
	
	return returnMe;
}
static inline NSAffineTransform * InverseTransformThatFitsRectInRect(NSRect a, NSRect b, SizingMode m)	{
	NSRect				r = NSRectThatFitsRectInRect(a, b, m);
	NSAffineTransform	*returnMe = [NSAffineTransform transform];
	NSAffineTransform	*tmp = nil;
	
	tmp = [NSAffineTransform transform];
	[tmp translateXBy:-1*r.origin.x yBy:-1*r.origin.y];
	[returnMe appendTransform:tmp];
	
	tmp = [NSAffineTransform transform];
	[tmp scaleXBy:a.size.width/r.size.width yBy:a.size.height/r.size.height];
	[returnMe appendTransform:tmp];
	
	tmp = [NSAffineTransform transform];
	[tmp translateXBy:a.origin.x yBy:a.origin.y];
	[returnMe appendTransform:tmp];
	
	return returnMe;
}




static inline NSString * NSStringFromSizingMode(SizingMode inMode)	{
	switch (inMode)	{
	case SizingModeFit:			return @"Fit";
	case SizingModeFitWidth:	return @"FitWidth";
	case SizingModeFill:		return @"Fill";
	case SizingModeStretch:		return @"Stretch";
	case SizingModeCopy:		return @"Copy";
	}
	return @"???";
}
static inline SizingMode SizingModeFromNSString(NSString *inString)	{
	if (inString == nil)
		return SizingModeFit;
	
	if ([inString isEqualToString:NSStringFromSizingMode(SizingModeFit)])
		return SizingModeFit;
	if ([inString isEqualToString:NSStringFromSizingMode(SizingModeFitWidth)])
		return SizingModeFitWidth;
	if ([inString isEqualToString:NSStringFromSizingMode(SizingModeFill)])
		return SizingModeFill;
	if ([inString isEqualToString:NSStringFromSizingMode(SizingModeStretch)])
		return SizingModeStretch;
	if ([inString isEqualToString:NSStringFromSizingMode(SizingModeCopy)])
		return SizingModeCopy;
	
	return SizingModeFit;
}








#endif /* SizingTool_objc_h */
