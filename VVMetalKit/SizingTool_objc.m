//
//  SizingTool_c.m
//  VVMetalKit
//
//  Created by testAdmin on 4/27/21.
//

#import "SizingTool_objc.h"




GPoint GPointFromNSPoint(NSPoint inPoint)	{
	struct GPoint		returnMe = { inPoint.x, inPoint.y };
	return returnMe;
}
GPoint GPointFromCGPoint(CGPoint inPoint)	{
	struct GPoint		returnMe = { inPoint.x, inPoint.y };
	return returnMe;
}








GSize GSizeFromNSSize(NSSize inSize)	{
	struct GSize		returnMe = { inSize.width, inSize.height };
	return returnMe;
}
GSize GSizeFromCGSize(CGSize inSize)	{
	struct GSize		returnMe = { inSize.width, inSize.height };
	return returnMe;
}








GRect GRectFromCGRect(CGRect inRect)	{
	struct GRect		returnMe = { { inRect.origin.x, inRect.origin.y }, { inRect.size.width, inRect.size.height } };
	return returnMe;
}
GRect GRectFromNSRect(NSRect inRect)	{
	struct GRect		returnMe = { { inRect.origin.x, inRect.origin.y }, { inRect.size.width, inRect.size.height } };
	return returnMe;
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

