#ifndef SizingTool_c_h
#define SizingTool_c_h

#include <stdio.h>
#include <stdbool.h>
#import <TargetConditionals.h>
#if defined(TARGET_OS_IOS) && TARGET_OS_IOS==1
#include <VVMetalKitTouch/SizingToolTypes.h>
#else
#include <VVMetalKit/SizingToolTypes.h>
#endif
#include <math.h>




static inline GPoint MakePoint(float inX, float inY);
static inline bool GPointsEqual(GPoint inA, GPoint inB);

static inline GSize MakeSize(float inWidth, float inHeight);
static inline bool GSizesEqual(GSize inA, GSize inB);

static inline GRect MakeRect(float inX, float inY, float inW, float inH);
static inline GRect MakeRectFromVals(GPoint inPt, GSize inSize);
static inline bool GRectsEqual(GRect inA, GRect inB);

static inline GRect RectThatFitsRectInRect(GRect inSrcRect, GRect inDstRect, SizingMode mode);

static inline bool PointInRect(GPoint inPoint, GRect inRect);

static inline float MaxX(GRect inRect);
static inline float MinX(GRect inRect);
static inline float MaxY(GRect inRect);
static inline float MinY(GRect inRect);

static inline GPoint NormCoordsOfPointInRect(GPoint inPoint, GRect inRect);

static inline GPoint NormCoordsOfPixelInRect(GPoint inPoint, GRect inRect);
static inline GPoint PixelForNormCoordsInRect(GPoint inPoint, GRect inRect);




static inline GPoint MakePoint(float inX, float inY)	{
	struct GPoint		returnMe = { inX, inY };
	return returnMe;
}
static inline bool GPointsEqual(GPoint inA, GPoint inB)	{
	return (inA.x == inB.x && inA.y == inB.y);
}


static inline GSize MakeSize(float inWidth, float inHeight)	{
	struct GSize		returnMe = { inWidth, inHeight };
	return returnMe;
}
static inline bool GSizesEqual(GSize inA, GSize inB)	{
	return (inA.width == inB.width && inA.height == inB.height);
}




static inline GRect MakeRect(float inX, float inY, float inW, float inH)	{
	struct GRect		returnMe = { { inX, inY }, { inW, inH } };
	return returnMe;
}
static inline GRect MakeRectFromVals(GPoint inPt, GSize inSize)	{
	struct GRect		returnMe = { inPt, inSize };
	return returnMe;
}
static inline bool GRectsEqual(GRect inA, GRect inB)	{
	return (GPointsEqual(inA.origin, inB.origin) && GSizesEqual(inA.size, inB.size));
}




static inline GRect RectThatFitsRectInRect(GRect a, GRect b, SizingMode m)	{
	GRect		returnMe = { { 0., 0. }, { 0., 0. } };
	float			bAspect = b.size.width/b.size.height;
	float			aAspect = a.size.width/a.size.height;
	switch (m)	{
	case SizingModeFit:
		//	if the rect i'm trying to fit stuff *into* is wider than the rect i'm resizing
		if (bAspect > aAspect)	{
			returnMe.size.height = b.size.height;
			returnMe.size.width = returnMe.size.height * aAspect;
		}
		//	else if the rect i'm resizing is wider than the rect it's going into
		else if (bAspect < aAspect)	{
			returnMe.size.width = b.size.width;
			returnMe.size.height = returnMe.size.width / aAspect;
		}
		else	{
			returnMe.size.width = b.size.width;
			returnMe.size.height = b.size.height;
		}
		returnMe.origin.x = (b.size.width-returnMe.size.width)/2.0+b.origin.x;
		returnMe.origin.y = (b.size.height-returnMe.size.height)/2.0+b.origin.y;
		break;
	case SizingModeFitWidth:
		//	make a rect with the target width, calculate its height
		returnMe.size.width = b.size.width;
		returnMe.origin.x = b.origin.x;
		returnMe.size.height = returnMe.size.width/aAspect;
		returnMe.origin.y = b.origin.y + ( (b.size.height - returnMe.size.height)/2.0 );
		break;
	case SizingModeFill:
		//	if the rect i'm trying to fit stuff *into* is wider than the rect i'm resizing
		if (bAspect > aAspect)	{
			returnMe.size.width = b.size.width;
			returnMe.size.height = returnMe.size.width / aAspect;
		}
		//	else if the rect i'm resizing is wider than the rect it's going into
		else if (bAspect < aAspect)	{
			returnMe.size.height = b.size.height;
			returnMe.size.width = returnMe.size.height * aAspect;
		}
		else	{
			returnMe.size.width = b.size.width;
			returnMe.size.height = b.size.height;
		}
		returnMe.origin.x = (b.size.width-returnMe.size.width)/2.0+b.origin.x;
		returnMe.origin.y = (b.size.height-returnMe.size.height)/2.0+b.origin.y;
		break;
	case SizingModeStretch:
		returnMe = MakeRect(b.origin.x, b.origin.y, b.size.width, b.size.height);
		break;
	case SizingModeCopy:
		//	draw "a" at its provided size (don't resize at all), centered in "b".  make sure all coords are snapped to nearest pixel.
		returnMe.size = MakeSize( round(a.size.width), round(a.size.height) );
		returnMe.origin.x = round((b.size.width-returnMe.size.width)/2.0+b.origin.x);
		returnMe.origin.y = round((b.size.height-returnMe.size.height)/2.0+b.origin.y);
		break;
	}
	return returnMe;
	
	
	//return float4(0,0,0,0);
	//return MakeRect(0., 0., 0., 0.);
}


//static inline bool PointInRect(GPoint inPoint, GRect inRect)	{
//	if (inPoint.x < MinX(inRect) || inPoint.x > MaxX(inRect))
//		return false;
//	if (inPoint.y < MinY(inRect) || inPoint.y > MaxY(inRect))
//		return false;
//	return true;
//}
static inline bool PointInRect(GPoint inPoint, GRect inRect)	{
	if (inPoint.x < MinX(inRect) || inPoint.x > MaxX(inRect))
		return false;
	if (inPoint.y < MinY(inRect) || inPoint.y > MaxY(inRect))
		return false;
	return true;
}


static inline float MaxX(GRect inRect)	{
	if (inRect.size.width > 0.)
		return inRect.origin.x + inRect.size.width;
	else
		return inRect.origin.x;
}
static inline float MinX(GRect inRect)	{
	if (inRect.size.width > 0.)
		return inRect.origin.x;
	else
		return inRect.origin.x + inRect.size.width;
}
static inline float MaxY(GRect inRect)	{
	if (inRect.size.height > 0.)
		return inRect.origin.y + inRect.size.height;
	else
		return inRect.origin.y;
}
static inline float MinY(GRect inRect)	{
	if (inRect.size.height > 0.)
		return inRect.origin.y;
	else
		return inRect.origin.y + inRect.size.height;
}


static inline GPoint NormCoordsOfPointInRect(GPoint inPoint, GRect inRect)	{
	GPoint		localCoords = MakePoint(inPoint.x - inRect.origin.x, inPoint.y - inRect.origin.y);
	return MakePoint( localCoords.x/inRect.size.width, localCoords.y/inRect.size.height );
}


static inline GPoint NormCoordsOfPixelInRect(GPoint inPoint, GRect inRect)	{
	GPoint		localCoords = MakePoint(inPoint.x - inRect.origin.x, inPoint.y - inRect.origin.y);
	return MakePoint( localCoords.x/(inRect.size.width-1.), localCoords.y/(inRect.size.height-1.) );
}
static inline GPoint PixelForNormCoordsInRect(GPoint inPoint, GRect inRect)	{
	return MakePoint( (inPoint.x*(inRect.size.width-1.))+inRect.origin.x, (inPoint.y*(inRect.size.height-1.))+inRect.origin.y );
}




#endif /* SizingTool_c_h */
