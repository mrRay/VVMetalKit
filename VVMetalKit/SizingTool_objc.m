//
//  SizingTool_c.m
//  VVMetalKit
//
//  Created by testAdmin on 4/27/21.
//

#import "SizingTool_objc.h"
#import "TargetConditionals.h"




#if !TARGET_OS_IOS
GPoint GPointFromNSPoint(NSPoint inPoint)	{
	struct GPoint		returnMe = { inPoint.x, inPoint.y };
	return returnMe;
}
NSPoint NSPointFromGPoint(GPoint inPoint)	{
	return NSMakePoint(inPoint.x, inPoint.y);
}
#endif
GPoint GPointFromCGPoint(CGPoint inPoint)	{
	struct GPoint		returnMe = { inPoint.x, inPoint.y };
	return returnMe;
}
CGPoint CGPointFromGPoint(GPoint inPoint)	{
	return CGPointMake(inPoint.x, inPoint.y);
}








#if !TARGET_OS_IOS
GSize GSizeFromNSSize(NSSize inSize)	{
	struct GSize		returnMe = { inSize.width, inSize.height };
	return returnMe;
}
NSSize NSSizeFromGSize(GSize inSize)	{
	return NSMakeSize(inSize.width, inSize.height);
}
#endif
GSize GSizeFromCGSize(CGSize inSize)	{
	struct GSize		returnMe = { inSize.width, inSize.height };
	return returnMe;
}
CGPoint CGSizeFromGSize(GSize inSize)	{
	return CGPointMake(inSize.width, inSize.height);
}








#if !TARGET_OS_IOS
GRect GRectFromNSRect(NSRect inRect)	{
	struct GRect		returnMe = { { inRect.origin.x, inRect.origin.y }, { inRect.size.width, inRect.size.height } };
	return returnMe;
}
NSRect NSRectFromGRect(GRect inRect)	{
	return NSMakeRect(inRect.origin.x, inRect.origin.y, inRect.size.width, inRect.size.height);
}
#endif
GRect GRectFromCGRect(CGRect inRect)	{
	struct GRect		returnMe = { { inRect.origin.x, inRect.origin.y }, { inRect.size.width, inRect.size.height } };
	return returnMe;
}
CGRect CGRectFromGRect(GRect inRect)	{
	return CGRectMake(inRect.origin.x, inRect.origin.y, inRect.size.width, inRect.size.height);
}






NSString * NSStringFromGRect(GRect inRect)	{
	return [NSString stringWithFormat:@"<GRect %@ %@>",NSStringFromGPoint(inRect.origin),NSStringFromGSize(inRect.size)];
}
NSString * NSStringFromGSize(GSize inSize)	{
	return [NSString stringWithFormat:@"<GSize %0.2f x%0.2f>",inSize.width,inSize.height];
}
NSString * NSStringFromGPoint(GPoint inPoint)	{
	return [NSString stringWithFormat:@"<GPoint %0.2f, %0.2f>",inPoint.x,inPoint.y];
}




NSRect NSRectThatFitsRectInRect(NSRect inSrcRect, NSRect inDstRect, SizingMode mode)	{
	GRect		srcRect = GRectFromNSRect(inSrcRect);
	GRect		dstRect = GRectFromNSRect(inDstRect);
	GRect		returnMe = RectThatFitsRectInRect(srcRect, dstRect, mode);
	return NSRectFromGRect(returnMe);
}




NSAffineTransform * TransformThatFitsRectInRect(NSRect a, NSRect b, SizingMode m)	{
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
NSAffineTransform * InverseTransformThatFitsRectInRect(NSRect a, NSRect b, SizingMode m)	{
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




NSString * NSStringFromSizingMode(SizingMode inMode)	{
	switch (inMode)	{
	case SizingModeFit:			return @"Fit";
	case SizingModeFitWidth:	return @"FitWidth";
	case SizingModeFill:		return @"Fill";
	case SizingModeStretch:		return @"Stretch";
	case SizingModeCopy:		return @"Copy";
	}
	return @"???";
}
SizingMode SizingModeFromNSString(NSString *inString)	{
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

