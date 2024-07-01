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


static inline VVPOINT VVRectGetAnchorPoint(VVRECT inRect, VVRectAnchor inAnchor);
static inline VVRECT VVMakeAnchoredRect(VVPOINT inPt, VVSIZE inSize, VVRectAnchor inAnchor);
static inline VVRECT VVRectAnchorSetFrameSize(VVRECT inRect, VVSIZE newSize, VVRectAnchor inAnchor);


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




static inline VVRECT VVRectNormalizeSize(VVRECT inRect);
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






#endif /* VVMacros_h */
