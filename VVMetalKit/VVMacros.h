//
//  VVMacros.h
//  VVFontAtlas
//
//  Created by testadmin on 5/9/23.
//

#import <TargetConditionals.h>

#ifndef VVMacros_h
#define VVMacros_h




//	NSRect/Point/Size/etc and CGRect/Point/Size are functionally identical, but cast differently.  these macros provide a single interface for this functionality to simplify things.
#if defined(TARGET_OS_IOS) && TARGET_OS_IOS==1
#define VVPOINT CGPoint
#define VVMAKEPOINT CGPointMake
#define VVZEROPOINT CGPointZero
#define VVRECT CGRect
#define VVMAKERECT CGRectMake
#define VVZERORECT CGRectZero
#define VVINSETRECT(a,dx,dy) CGRectMake(a.origin.x+(dx/2.0),a.origin.y+(dy/2.0),a.size.width-dx,a.size.height-dy)
#define VVINTERSECTSRECT CGRectIntersectsRect
#define VVINTERSECTIONRECT CGRectIntersection
#define VVINTEGRALRECT CGRectIntegral
#define VVUNIONRECT CGRectUnion
#define VVPOINTINRECT(a,b) CGRectContainsPoint((b),(a))
#define VVSIZE CGSize
#define VVMAKESIZE CGSizeMake
#else
#define VVPOINT NSPoint
#define VVMAKEPOINT NSMakePoint
#define VVZEROPOINT NSZeroPoint
#define VVINSETRECT NSInsetRect
#define VVRECT NSRect
#define VVMAKERECT NSMakeRect
#define VVZERORECT NSZeroRect
#define VVINTERSECTSRECT NSIntersectsRect
#define VVINTERSECTIONRECT NSIntersectionRect
#define VVINTEGRALRECT NSIntegralRect
#define VVUNIONRECT NSUnionRect
#define VVPOINTINRECT NSPointInRect
#define VVSIZE NSSize
#define VVMAKESIZE NSMakeSize
#endif




//	macros for calculating rect coords
/*
#define VVMINX(r) (r.origin.x)
#define VVMAXX(r) (r.origin.x+r.size.width)
#define VVMINY(r) (r.origin.y)
#define VVMAXY(r) (r.origin.y+r.size.height)
#define VVMIDX(r) (r.origin.x+(r.size.width/2.0))
#define VVMIDY(r) (r.origin.y+(r.size.height/2.0))

#define VVMINX(r) (fmin(r.origin.x,(r.origin.x+r.size.width)))
#define VVMAXX(r) (fmax(r.origin.x,(r.origin.x+r.size.width)))
#define VVMINY(r) (fmin(r.origin.y,(r.origin.y+r.size.height)))
#define VVMAXY(r) (fmax(r.origin.y,(r.origin.y+r.size.height)))
*/
#define VVMINX(r) ((r.size.width>=0) ? (r.origin.x) : (r.origin.x+r.size.width))
#define VVMAXX(r) ((r.size.width>=0) ? (r.origin.x+r.size.width) : (r.origin.x))
#define VVMINY(r) ((r.size.height>=0) ? (r.origin.y) : (r.origin.y+r.size.height))
#define VVMAXY(r) ((r.size.height>=0) ? (r.origin.y+r.size.height) : (r.origin.y))
#define VVMIDX(r) (r.origin.x+(r.size.width/2.0))
#define VVMIDY(r) (r.origin.y+(r.size.height/2.0))
#define VVTOPLEFT(r) (VVMAKEPOINT(VVMINX(r),VVMAXY(r)))
#define VVTOPRIGHT(r) (VVMAKEPOINT(VVMAXX(r),VVMAXY(r)))
#define VVBOTLEFT(r) (VVMAKEPOINT(VVMINX(r),VVMINY(r)))
#define VVBOTRIGHT(r) (VVMAKEPOINT(VVMAXX(r),VVMINY(r)))
#define VVCENTER(r) (VVMAKEPOINT(VVMIDX(r),VVMIDY(r)))
#define VVADDPOINT(a,b) (VVMAKEPOINT((a.x+b.x),(a.y+b.y)))
#define VVSUBPOINT(a,b) (VVMAKEPOINT((a.x-b.x),(a.y-b.y)))
#define VVADDSIZE(a,b) (VVMAKESIZE(a.width+b.width, a.height+b.height))
#define VVSUBSIZE(a,b) (VVMAKESIZE(a.width-b.width, a.height-b.height))
#define VVEQUALRECTS(a,b) ((a.origin.x==b.origin.x && a.origin.y==b.origin.y && a.size.width==b.size.width && a.size.height==b.size.height) ? YES : NO)
#define VVEQUALSIZES(a,b) ((a.width==b.width)&&(a.height==b.height))
#define VVEQUALPOINTS(a,b) ((a.x==b.x)&&(a.y==b.y))
#define VVISZERORECT(a) ((a.size.width==0.0 && a.size.height==0.0) ? YES : NO)
#define VVPOINTDISTANCE(a,b) fabs(sqrtf((a.x-b.x)*(a.x-b.x) + (a.y-b.y)*(a.y-b.y)))




//	when we're creating, moving, and sizing rects, it's useful to be able to specify the operations relative to anchor points on the rects.
typedef NS_ENUM(NSUInteger, VVRectAnchor)	{
	VVRectAnchor_Center = 0,
	VVRectAnchor_TL,	//	top-left corner
	VVRectAnchor_TR,	//	top-right corner
	VVRectAnchor_BL,	//	bottom-left corner
	VVRectAnchor_BR,	//	bottom-right corner
	VVRectAnchor_TM,	//	middle of top top side
	VVRectAnchor_RM,	//	middle of right side
	VVRectAnchor_BM,	//	middle of bottom side
	VVRectAnchor_LM		//	middle of left side
};


//	Returns the coordinations of the point in the passed rect that corresponds to the passed anchor position.
static inline VVPOINT VVRectGetAnchorPoint(VVRECT inRect, VVRectAnchor inAnchor);
//	Makes a rect with the passed size, positioned such that the passed point will by located in the passed anchor position. A call equivalent to `NSMakeRect(0,0,10,10);` would be `VVMakeAnchoredRect(NSMakePoint(0,0), NSMakeSize(10,10), VVRectAnchor_BL);`
static inline VVRECT VVMakeAnchoredRect(VVPOINT inPt, VVSIZE inSize, VVRectAnchor inAnchor);
//	Changes the passed rect's size to a new value. The geometric origin of the size change is the passed anchor.
static inline VVRECT VVRectAnchorSetFrameSize(VVRECT inRect, VVSIZE newSize, VVRectAnchor inAnchor);
//	Adjusts the passed rect's size by the passed dimensions. The geometric origin of the size change is the passed anchor.
static inline VVRECT VVRectAnchorAdjustFrameSize(VVRECT inRect, double inDeltaX, double inDeltaY, VVRectAnchor inAnchor);
//	Returns the anchor located on the opposite side of the rect from the passed anchor (with the exception of Center, which returns Center);
static inline VVRectAnchor VVRectAnchorGetOpposite(VVRectAnchor inAnchor);
//	Returns an array of NSNumber instances that correspond to VVRectAnchor enum values. Returns constituent anchors for compound anchors- passing this TL would return [TM,LM], passing it Center would return [LM,TM,RM,BM], etc.
static inline NSArray<NSNumber*> * VVRectAnchorGetConstituentAnchors(VVRectAnchor inAnchor);
//	Returns a human-readable string describing the passed anchor
static inline NSString * NSStringFromVVRectAnchor(VVRectAnchor n);
//	Calculates the VVRectAnchor value that most closely corresponds to the passed string
static inline VVRectAnchor VVRectAnchorFromNSString(NSString *n);


static inline VVPOINT VVRectGetAnchorPoint(VVRECT inRect, VVRectAnchor inAnchor)	{
	VVPOINT		returnMe = inRect.origin;
	switch (inAnchor)	{
	case VVRectAnchor_Center:
		returnMe = VVADDPOINT( inRect.origin, VVMAKEPOINT(inRect.size.width/2.,inRect.size.height/2.) );
		break;
	case VVRectAnchor_TL:
		returnMe = VVADDPOINT( inRect.origin, VVMAKEPOINT(0., inRect.size.height) );
		break;
	case VVRectAnchor_TR:
		returnMe = VVADDPOINT( inRect.origin, VVMAKEPOINT(inRect.size.width, inRect.size.height) );
		break;
	case VVRectAnchor_BL:
		//	do nothing- rect's origin is already the bottom left!
		break;
	case VVRectAnchor_BR:
		returnMe = VVADDPOINT( inRect.origin, VVMAKEPOINT(inRect.size.width, 0.) );
		break;
	case VVRectAnchor_TM:
		returnMe = VVADDPOINT( inRect.origin, VVMAKEPOINT(inRect.size.width/2., inRect.size.height) );
		break;
	case VVRectAnchor_RM:
		returnMe = VVADDPOINT( inRect.origin, VVMAKEPOINT(inRect.size.width, inRect.size.height/2.) );
		break;
	case VVRectAnchor_BM:
		returnMe = VVADDPOINT( inRect.origin, VVMAKEPOINT(inRect.size.width/2., 0.) );
		break;
	case VVRectAnchor_LM:
		returnMe = VVADDPOINT( inRect.origin, VVMAKEPOINT(0., inRect.size.height/2.) );
		break;
	}
	return returnMe;
}
static inline VVRECT VVMakeAnchoredRect(VVPOINT inPt, VVSIZE inSize, VVRectAnchor inAnchor)	{
	VVRECT		returnMe = VVMAKERECT(inPt.x, inPt.y, inSize.width, inSize.height);
	switch(inAnchor)	{
	case VVRectAnchor_Center:
		returnMe.origin = VVSUBPOINT( returnMe.origin, VVMAKEPOINT(inSize.width/2., inSize.height/2.) );
		break;
	case VVRectAnchor_TL:	//	origin moves from BL to TL
		returnMe.origin = VVSUBPOINT( returnMe.origin, VVMAKEPOINT(0., inSize.height) );
		break;
	case VVRectAnchor_TR:	//	origin moves from BL to  TR
		returnMe.origin = VVSUBPOINT( returnMe.origin, VVMAKEPOINT(inSize.width, inSize.height) );
		break;
	case VVRectAnchor_BL:	//	no-op: origin of an NSRect/CGRect is already bottom-left!
		break;
	case VVRectAnchor_BR:	//	origin moves from BL to BR
		returnMe.origin = VVSUBPOINT( returnMe.origin, VVMAKEPOINT(inSize.width, 0.) );
		break;
	case VVRectAnchor_TM:	//	origin moves from BL to TM
		returnMe.origin = VVSUBPOINT( returnMe.origin, VVMAKEPOINT(inSize.width/2., inSize.height) );
		break;
	case VVRectAnchor_RM:	//	origin moves from BL to RM
		returnMe.origin = VVSUBPOINT( returnMe.origin, VVMAKEPOINT(inSize.width, inSize.height/2.) );
		break;
	case VVRectAnchor_BM:	//	origin moves from BL to BM
		returnMe.origin = VVSUBPOINT( returnMe.origin, VVMAKEPOINT(inSize.width/2., 0.) );
		break;
	case VVRectAnchor_LM:	//	origin moves from BL to LM
		returnMe.origin = VVSUBPOINT( returnMe.origin, VVMAKEPOINT(0., inSize.height/2.) );
		break;
	}
	
	return returnMe;
}
static inline VVRECT VVRectAnchorSetFrameSize(VVRECT inRect, VVSIZE newSize, VVRectAnchor inAnchor)	{
	VVPOINT			anchorPoint = VVRectGetAnchorPoint(inRect, inAnchor);
	return VVMakeAnchoredRect(anchorPoint, newSize, inAnchor);
}
static inline VVRECT VVRectAnchorAdjustFrameSize(VVRECT inRect, double inDeltaX, double inDeltaY, VVRectAnchor inAnchor)	{
	VVSIZE			newSize = VVMAKESIZE(inRect.size.width + inDeltaX, inRect.size.height + inDeltaY);
	VVPOINT			anchorPoint = VVRectGetAnchorPoint(inRect, inAnchor);
	return VVMakeAnchoredRect(anchorPoint, newSize, inAnchor);
}
static inline VVRectAnchor VVRectAnchorGetOpposite(VVRectAnchor inAnchor)	{
	switch (inAnchor)	{
	case VVRectAnchor_Center:	return VVRectAnchor_Center;
	case VVRectAnchor_TL:	return VVRectAnchor_BR;
	case VVRectAnchor_TR:	return VVRectAnchor_BL;
	case VVRectAnchor_BL:	return VVRectAnchor_TR;
	case VVRectAnchor_BR:	return VVRectAnchor_TL;
	case VVRectAnchor_TM:	return VVRectAnchor_BM;
	case VVRectAnchor_RM:	return VVRectAnchor_LM;
	case VVRectAnchor_BM:	return VVRectAnchor_TM;
	case VVRectAnchor_LM:	return VVRectAnchor_RM;
	}
	
	return VVRectAnchor_Center;
}
static inline NSArray<NSNumber*> * VVRectAnchorGetConstituentAnchors(VVRectAnchor inAnchor)	{
	NSMutableArray<NSNumber*>		*anchors = [NSMutableArray arrayWithCapacity:0];
	switch (inAnchor)	{
	case VVRectAnchor_Center:
		[anchors addObject:@(VVRectAnchor_LM)];
		[anchors addObject:@(VVRectAnchor_RM)];
		[anchors addObject:@(VVRectAnchor_TM)];
		[anchors addObject:@(VVRectAnchor_BM)];
		break;
	case VVRectAnchor_TL:
		[anchors addObject:@(VVRectAnchor_TM)];
		[anchors addObject:@(VVRectAnchor_LM)];
		break;
	case VVRectAnchor_TR:
		[anchors addObject:@(VVRectAnchor_TM)];
		[anchors addObject:@(VVRectAnchor_RM)];
		break;
	case VVRectAnchor_BL:
		[anchors addObject:@(VVRectAnchor_BM)];
		[anchors addObject:@(VVRectAnchor_LM)];
		break;
	case VVRectAnchor_BR:
		[anchors addObject:@(VVRectAnchor_BM)];
		[anchors addObject:@(VVRectAnchor_RM)];
		break;
	case VVRectAnchor_TM:
		[anchors addObject:@(VVRectAnchor_TM)];
		break;
	case VVRectAnchor_RM:
		[anchors addObject:@(VVRectAnchor_RM)];
		break;
	case VVRectAnchor_BM:
		[anchors addObject:@(VVRectAnchor_BM)];
		break;
	case VVRectAnchor_LM:
		[anchors addObject:@(VVRectAnchor_LM)];
		break;
	}
	return [NSArray arrayWithArray:anchors];
}
static inline NSString * NSStringFromVVRectAnchor(VVRectAnchor n)	{
	switch (n)	{
		case VVRectAnchor_Center:	return @"Center";
		case VVRectAnchor_TL:	return @"Top-Left";
		case VVRectAnchor_TR:	return @"Top-Right";
		case VVRectAnchor_BL:	return @"Bottom-Left";
		case VVRectAnchor_BR:	return @"Bottom-Right";
		case VVRectAnchor_TM:	return @"Top-Middle";
		case VVRectAnchor_RM:	return @"Right-Middle";
		case VVRectAnchor_BM:	return @"Bottom-Middle";
		case VVRectAnchor_LM:	return @"Left-Middle";
	}
	return nil;
}
static inline VVRectAnchor VVRectAnchorFromNSString(NSString *n)	{
	if (n == nil)
		return VVRectAnchor_Center;
	VVRectAnchor		anchors[] = {
		VVRectAnchor_Center,
		VVRectAnchor_TL,
		VVRectAnchor_TR,
		VVRectAnchor_BL,
		VVRectAnchor_BR,
		VVRectAnchor_TM,
		VVRectAnchor_RM,
		VVRectAnchor_BM,
		VVRectAnchor_LM
	};
	for (int i=0; i<sizeof(anchors)/sizeof(VVRectAnchor); ++i)	{
		NSString	*tmpStr = NSStringFromVVRectAnchor(anchors[i]);
		if (tmpStr == nil)
			continue;
		if ([n isEqualToString:tmpStr])	{
			return anchors[i];
		}
	}
	return VVRectAnchor_Center;
}




//	The returned rect will have the same exact dimensions as the passed rect, but the returend rect is guaranteed to have a width and height that are both >= 0
static inline VVRECT VVRectNormalizeSize(VVRECT inRect);
//	Same as 'VVRectNormalizeSize()', but it also rounds everything (both origin and size) to the nearest integer value
static inline VVRECT VVRectIntegralNormalizeSize(VVRECT inRect);


static inline VVRECT VVRectNormalizeSize(VVRECT inRect)	{
	if (inRect.size.width >= 0. && inRect.size.height >= 0.)
		return inRect;
	
	VVRECT			returnMe = inRect;
	if (returnMe.size.width < 0.)	{
		returnMe.origin.x += returnMe.size.width;
		returnMe.size.width = fabs(returnMe.size.width);
	}
	if (returnMe.size.height < 0.)	{
		returnMe.origin.y += returnMe.size.height;
		returnMe.size.height = fabs(returnMe.size.height);
	}
	return returnMe;
}
static inline VVRECT VVRectIntegralNormalizeSize(VVRECT inRect)	{
	VVRECT		returnMe = VVMAKERECT(round(inRect.origin.x), round(inRect.origin.y), round(inRect.size.width), round(inRect.size.height));
	
	if (returnMe.size.width >= 0. && returnMe.size.height >= 0.)
		return returnMe;
	if (returnMe.size.width < 0.)	{
		returnMe.origin.x = round(returnMe.origin.x + returnMe.size.width);
		returnMe.size.width = round(fabs(returnMe.size.width));
	}
	if (returnMe.size.height < 0.)	{
		returnMe.origin.y = round(returnMe.origin.y + returnMe.size.height);
		returnMe.size.height = round(fabs(returnMe.size.height));
	}
	return returnMe;
}




///	- Description: "Converts" the passed point from values that describe its location in a bottom-left coordinate space to values that describe that same location in a coordinate space that has its origin in the top-left corner of the passed bounds.
///	- Parameters:
///		- inPoint: The point to convert
///		- inBounds: The bounds in which the point will be converted. 'inBounds' describes a region in a bottom-left coordinate space.
///	- Returns: The same location, expressed in a coordinate space that has its origin in the top-left corner of 'inBounds'
static inline VVPOINT ConvertPointBLtoTL(VVPOINT inPoint, VVRECT inBounds);
static inline VVPOINT ConvertPointTLtoBL(VVPOINT inPoint, VVRECT inBounds);

static inline VVRECT ConvertRectBLtoTL(VVRECT inRect, VVRECT inBounds);
static inline VVRECT ConvertRectTLtoBL(VVRECT inRect, VVRECT inBounds);

static inline VVPOINT ConvertPointBLtoTL(VVPOINT inPoint, VVRECT inBounds)	{
	VVPOINT		boundsTopLeft = VVRectGetAnchorPoint(inBounds, VVRectAnchor_TL);
	VVPOINT		returnMe = NSMakePoint( (inPoint.x - boundsTopLeft.x), (boundsTopLeft.y - inPoint.y) );
	return returnMe;
}
static inline VVPOINT ConvertPointTLtoBL(VVPOINT inPoint, VVRECT inBounds)	{
	VVPOINT		boundsTopLeft = VVRectGetAnchorPoint(inBounds, VVRectAnchor_TL);
	VVPOINT		returnMe = NSMakePoint( (boundsTopLeft.x + inPoint.x), (boundsTopLeft.y - inPoint.y) );
	return returnMe;
}

static inline VVRECT ConvertRectBLtoTL(VVRECT inRect, VVRECT inBounds)	{
	VVPOINT		rectTopLeft = VVRectGetAnchorPoint(inRect, VVRectAnchor_TL);
	VVRECT		returnMe = inRect;
	returnMe.origin = ConvertPointBLtoTL(rectTopLeft, inBounds);
	return returnMe;
}
static inline VVRECT ConvertRectTLtoBL(VVRECT inRect, VVRECT inBounds)	{
	VVPOINT		rectBottomLeft = VVRectGetAnchorPoint(inRect, VVRectAnchor_TL);
	VVRECT		returnMe = inRect;
	returnMe.origin = ConvertPointTLtoBL(rectBottomLeft, inBounds);
	return returnMe;
}




//	macro for clipping a val to the normalized range (0.0 - 1.0)
#define CLIPNORM(n) (((n)<0.0)?0.0:(((n)>1.0)?1.0:(n)))
#define CLIPTORANGE(n,l,h) (((n)<(l))?(l):(((n)>(h))?(h):(n)))






//	macros for making a CGRect from an NSRect
#define NSMAKECGRECT(n) CGRectMake(n.origin.x, n.origin.y, n.size.width, n.size.height)
#define NSMAKECGPOINT(n) CGPointMake(n.x, n.y)
#define NSMAKECGSIZE(n) CGSizeMake(n.width, n.height)
//	macros for making an NSRect from a CGRect
#define CGMAKENSRECT(n) NSMakeRect(n.origin.x, n.origin.y, n.size.width, n.size.height)
#define CGMAKENSSIZE(n) NSMakeSize(n.width,n.height)


#define VVFMTSTRING(f, ...) ((NSString *)[NSString stringWithFormat:f, ##__VA_ARGS__])





//	simple bitmask check
#define A_HAS_B(a,b) (((a)&(b))==(b))




//	returns a human-readable string describing the CMTime
#define TIMEDESC(n) CMTimeCopyDescription(kCFAllocatorDefault,n)




#define ROUNDAUPTOMULTOFB(A,B) ((((A)%(B))==0) ? (A) : ((A) + ((B)-((A)%(B)))))






#endif /* VVMacros_h */
