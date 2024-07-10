#ifndef SizingTool_h
#define SizingTool_h

//#include <stdio.h>
//#include <stdbool.h>
//#import <TargetConditionals.h>

#if defined(TARGET_OS_IOS) && TARGET_OS_IOS==1
#include <VVMetalKitTouch/SizingToolTypes.h>
#else
#include <VVMetalKit/SizingToolTypes.h>
#endif


#ifdef __METAL_VERSION__




static inline GPoint MakePoint(float inX, float inY);
static inline bool GPointsEqual(GPoint inA, GPoint inB);

static inline GSize MakeSize(float inWidth, float inHeight);
static inline bool GSizesEqual(GSize inA, GSize inB);

static inline GRect MakeRect(float inX, float inY, float inW, float inH);
static inline GRect MakeRect(GPoint inPt, GSize inSize);
static inline bool GRectsEqual(GRect inA, GRect inB);

static inline GRect RectThatFitsRectInRect(GRect inSrcRect, GRect inDstRect, SizingMode mode);

static inline bool PointInRect(GPoint inPoint, GRect inRect);
static inline GPoint ClampPointToRect(GPoint inPoint, GRect inRect);
static inline bool PixelInRect(GPoint inPixel, GRect inRect);
static inline GPoint ClampPixelToRect(GPoint inPixel, GRect inRect);

static inline float MaxX(thread GRect & inRect);
static inline float MinX(thread GRect & inRect);
static inline float MaxY(thread GRect & inRect);
static inline float MinY(thread GRect & inRect);

static inline GPoint NormCoordsOfPointInRect(thread GPoint & inPoint, thread GRect & inRect);
static inline GPoint PointForNormCoordsInRect(thread GPoint & inPoint, thread GRect & inRect);

//static inline GPoint NormCoordsOfPixelInRect(thread GPoint & inPoint, thread GRect & inRect);
static inline GPoint NormCoordsOfPixelInRect(GPoint inPoint, GRect inRect);

//static inline GPoint PixelForNormCoordsInRect(thread GPoint & inPoint, thread GRect & inRect);
static inline GPoint PixelForNormCoordsInRect(GPoint inPoint, GRect inRect);


static inline GRange MakeGRange(int32_t inLocation, int32_t inLength);
static inline GRange MakeGRangeAbsolute(GRange inRange);
static inline GRange InvertGRangeLength(GRange inRange);








static inline GPoint MakePoint(float inX, float inY)	{
	return { inX, inY };
}
static inline bool GPointsEqual(GPoint inA, GPoint inB)	{
	return (inA.x == inB.x && inA.y == inB.y);
}


static inline GSize MakeSize(float inWidth, float inHeight)	{
	return { inWidth, inHeight };
}
bool GSizesEqual(GSize inA, GSize inB)	{
	return (inA.width == inB.width && inA.height == inB.height);
}


static inline GRect MakeRect(float inX, float inY, float inW, float inH)	{
	return { { inX, inY }, { inW, inH } };
}
static inline GRect MakeRect(GPoint inPt, GSize inSize)	{
	return { inPt, inSize };
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
		returnMe.size = { metal::round(a.size.width), metal::round(a.size.height) };
		returnMe.origin.x = metal::round((b.size.width-returnMe.size.width)/2.0+b.origin.x);
		returnMe.origin.y = metal::round((b.size.height-returnMe.size.height)/2.0+b.origin.y);
		break;
	}
	return returnMe;
	
	
	//return float4(0,0,0,0);
	//return MakeRect(0., 0., 0., 0.);
}


//static inline bool PointInRect(thread GPoint & inPoint, thread GRect & inRect)	{
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
static inline GPoint ClampPointToRect(GPoint inPoint, GRect inRect)	{
	return MakePoint( metal::clamp(inPoint.x, MinX(inRect), MaxX(inRect)), metal::clamp(inPoint.y, MinY(inRect), MaxY(inRect)) );
}


static inline bool PixelInRect(GPoint inPixel, GRect inRect)	{
	if (inPixel.x < MinX(inRect) || inPixel.x > (MaxX(inRect)-1))
		return false;
	if (inPixel.y < MinY(inRect) || inPixel.y > (MaxY(inRect)-1))
		return false;
	return true;
}
static inline GPoint ClampPixelToRect(GPoint inPixel, GRect inRect)	{
	return MakePoint( metal::clamp(inPixel.x, MinX(inRect), MaxX(inRect)-1), metal::clamp(inPixel.y, MinY(inRect), MaxY(inRect)-1) );
}


static inline float MaxX(thread GRect & inRect)	{
	if (inRect.size.width > 0.)
		return inRect.origin.x + inRect.size.width;
	else
		return inRect.origin.x;
}
static inline float MinX(thread GRect & inRect)	{
	if (inRect.size.width > 0.)
		return inRect.origin.x;
	else
		return inRect.origin.x + inRect.size.width;
}
static inline float MaxY(thread GRect & inRect)	{
	if (inRect.size.height > 0.)
		return inRect.origin.y + inRect.size.height;
	else
		return inRect.origin.y;
}
static inline float MinY(thread GRect & inRect)	{
	if (inRect.size.height > 0.)
		return inRect.origin.y;
	else
		return inRect.origin.y + inRect.size.height;
}


static inline GPoint NormCoordsOfPointInRect(thread GPoint & inPoint, thread GRect & inRect)	{
	GPoint		localCoords = MakePoint(inPoint.x - inRect.origin.x, inPoint.y - inRect.origin.y);
	return MakePoint( localCoords.x/inRect.size.width, localCoords.y/inRect.size.height );
	//float2		localCoords = float2(inPoint.x - inRect.origin.x, inPoint.y - inRect.origin.y);
	//return float2( localCoords.x/inRect.size.width, localCoords.y/inRect.size.height );
}

static inline GPoint PointForNormCoordsInRect(thread GPoint & inPoint, thread GRect & inRect)	{
	return MakePoint( (inPoint.x*(inRect.size.width))+inRect.origin.x, (inPoint.y*(inRect.size.height))+inRect.origin.y );
}


//static inline GPoint NormCoordsOfPixelInRect(thread GPoint & inPoint, thread GRect & inRect)	{
//	GPoint		localCoords = MakePoint(inPoint.x - inRect.origin.x, inPoint.y - inRect.origin.y);
//	return MakePoint( localCoords.x/(inRect.size.width-1.), localCoords.y/(inRect.size.height-1.) );
//}
static inline GPoint NormCoordsOfPixelInRect(GPoint inPoint, GRect inRect)	{
	GPoint		localCoords = MakePoint(inPoint.x - inRect.origin.x, inPoint.y - inRect.origin.y);
	return MakePoint( localCoords.x/(inRect.size.width-1.), localCoords.y/(inRect.size.height-1.) );
}
//static inline GPoint PixelForNormCoordsInRect(thread GPoint & inPoint, thread GRect & inRect)	{
//	return MakePoint( (inPoint.x*(inRect.size.width-1.))+inRect.origin.x, (inPoint.y*(inRect.size.height-1.))+inRect.origin.y );
//}
static inline GPoint PixelForNormCoordsInRect(GPoint inPoint, GRect inRect)	{
	return MakePoint( (inPoint.x*(inRect.size.width-1.))+inRect.origin.x, (inPoint.y*(inRect.size.height-1.))+inRect.origin.y );
}




static inline GRange MakeGRange(int32_t inLocation, int32_t inLength)	{
	GRange		returnMe;
	returnMe.location = inLocation;
	returnMe.length = inLength;
	return returnMe;
}
static inline GRange MakeGRangeAbsolute(GRange inRange)	{
	if (inRange.length >= 0 || inRange.location == GRangeLocationNotFound)
		return inRange;
	return InvertGRangeLength(inRange);
}
static inline GRange InvertGRangeLength(GRange inRange)	{
	GRange		returnMe;
	returnMe.length = inRange.length * -1;
	returnMe.location = inRange.location - returnMe.length;
	return returnMe;
}




#endif




#endif /* SizingTool_h */
