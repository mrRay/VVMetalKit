#ifndef SizingToolTypes_h
#define SizingToolTypes_h




///	Describes various sizing modes
typedef enum SizingMode	{
	SizingModeFit = 0,	///	Sizes one object to fit within another without cropping or altering its aspect ratio.  May result in letter- or pillar-boxing.
	SizingModeFitWidth,	///	Sizes one object to fit within another such that the first object's width fully occupies the second object's width.  If there's an aspect ratio mismatch, this may result in the first object being cropped or letter/pillarboxed.
	SizingModeFill,	///	Sizes one object to fit within another such that the second object is completely filled with the first object.  If there's an aspect ratio mismatch, this will result in the first object being cropped.
	SizingModeStretch,	///	Sizes one object to fit within another such that the first object's aspect ratio is modified to match the second's, which is fully occupied.
	SizingModeCopy	///	Copies one object into the other- neither the size nor aspect ratio is changed.
} SizingMode;


///	Describes the size of a two-dimensional object.  Exists mainly to share geometry data types between CPU and GPU.
typedef struct GSize	{
	float		width;
	float		height;
} GSize;


///	Describes a point in two-dimensional space.  Exists mainly to share geometry data types between CPU and GPU.
typedef struct GPoint	{
	float		x;
	float		y;
} GPoint;


///	Describes a rectangle in two-dimensional space.  Exists mainly to share geometry data types between CPU and GPU.
typedef struct GRect	{
	GPoint			origin;
	GSize			size;
} GRect;


///	Describes a range of integer values.  Exists mainly to share geometry data types between CPU and GPU.
typedef struct GRange	{
	int32_t		location;	///	If GRangeLocationNotFound, the location was not found
	int32_t		length;
} GRange;

#define GRangeLocationNotFound 0x7FFFFFFF




#ifdef __METAL_VERSION__

#include <metal_stdlib>
#include <metal_math>
using namespace metal;

#else

#include <math.h>

#endif	//	__METAL_VERSION__




#define PI (3.1415926535897932384626433832795)
#define DEG2RAD (PI/180.)
#define RAD2DEG (180./PI)




static inline GPoint MakePoint(float inX, float inY);
static inline bool GPointsEqual(GPoint inA, GPoint inB);

static inline GSize MakeSize(float inWidth, float inHeight);
static inline bool GSizesEqual(GSize inA, GSize inB);

static inline GRect MakeRect(float inX, float inY, float inW, float inH);
static inline GRect MakeRectFromVals(GPoint inPt, GSize inSize);
static inline bool GRectsEqual(GRect inA, GRect inB);

static inline GRect RectThatFitsRectInRect(GRect inSrcRect, GRect inDstRect, SizingMode mode);

static inline bool PointInRect(GPoint inPoint, GRect inRect);
static inline GPoint ClampPointToRect(GPoint inPoint, GRect inRect);
static inline bool PixelInRect(GPoint inPixel, GRect inRect);
static inline GPoint ClampPixelToRect(GPoint inPixel, GRect inRect);

static inline float MaxX(GRect inRect);
static inline float MinX(GRect inRect);
static inline float MaxY(GRect inRect);
static inline float MinY(GRect inRect);

static inline GPoint NormCoordsOfPointInRect(GPoint inPoint, GRect inRect);
static inline GPoint PointForNormCoordsInRect(GPoint inPoint, GRect inRect);

static inline GPoint NormCoordsOfPixelInRect(GPoint inPoint, GRect inRect);
static inline GPoint PixelForNormCoordsInRect(GPoint inPoint, GRect inRect);


//	"polar" GPoints have the format (r, theta in degrees)
static inline GPoint CarToPol(GPoint inPoint);
static inline GPoint PolToCar(GPoint inPoint);


static inline GRange MakeGRange(int32_t inLocation, int32_t inLength);
static inline GRange MakeGRangeAbsolute(GRange inRange);
static inline GRange InvertGRangeLength(GRange inRange);




static inline GPoint MakePoint(float inX, float inY)	{
	struct GPoint		returnMe = { inX, inY };
	return returnMe;
	//return { inX, inY };
}
static inline bool GPointsEqual(GPoint inA, GPoint inB)	{
	return (inA.x == inB.x && inA.y == inB.y);
	//return (inA.x == inB.x && inA.y == inB.y);
}


static inline GSize MakeSize(float inWidth, float inHeight)	{
	struct GSize		returnMe = { inWidth, inHeight };
	return returnMe;
	//return { inWidth, inHeight };
}
static inline bool GSizesEqual(GSize inA, GSize inB)	{
	return (inA.width == inB.width && inA.height == inB.height);
	//return (inA.width == inB.width && inA.height == inB.height);
}




static inline GRect MakeRect(float inX, float inY, float inW, float inH)	{
	struct GRect		returnMe = { { inX, inY }, { inW, inH } };
	return returnMe;
	//return { { inX, inY }, { inW, inH } };
}
static inline GRect MakeRectFromVals(GPoint inPt, GSize inSize)	{
	struct GRect		returnMe = { inPt, inSize };
	return returnMe;
	//return { inPt, inSize };
}
static inline bool GRectsEqual(GRect inA, GRect inB)	{
	return (GPointsEqual(inA.origin, inB.origin) && GSizesEqual(inA.size, inB.size));
	//return (GPointsEqual(inA.origin, inB.origin) && GSizesEqual(inA.size, inB.size));
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
static inline GPoint ClampPointToRect(GPoint inPoint, GRect inRect)	{
	//return MakePoint( clamp(inPoint.x, MinX(inRect), MaxX(inRect)), clamp(inPoint.y, MinY(inRect), MaxY(inRect)) );
	return MakePoint( fmin(fmax(inPoint.x, MinX(inRect)), MaxX(inRect)), fmin(fmax(inPoint.y, MinY(inRect)), MaxY(inRect)) );
}


static inline bool PixelInRect(GPoint inPixel, GRect inRect)	{
	if (inPixel.x < MinX(inRect) || inPixel.x > (MaxX(inRect)-1))
		return false;
	if (inPixel.y < MinY(inRect) || inPixel.y > (MaxY(inRect)-1))
		return false;
	return true;
}
static inline GPoint ClampPixelToRect(GPoint inPixel, GRect inRect)	{
	//return MakePoint( clamp(inPixel.x, MinX(inRect), MaxX(inRect)-1), clamp(inPixel.y, MinY(inRect), MaxY(inRect)-1) );
	return MakePoint( fmin(fmax(inPixel.x, MinX(inRect)), MaxX(inRect)-1), fmin(fmax(inPixel.y, MinY(inRect)), MaxY(inRect)-1) );
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
static inline GPoint PointForNormCoordsInRect(GPoint inPoint, GRect inRect)	{
	return MakePoint( (inPoint.x*(inRect.size.width))+inRect.origin.x, (inPoint.y*(inRect.size.height))+inRect.origin.y );
}


static inline GPoint NormCoordsOfPixelInRect(GPoint inPoint, GRect inRect)	{
	GPoint		localCoords = MakePoint(inPoint.x - inRect.origin.x, inPoint.y - inRect.origin.y);
	return MakePoint( localCoords.x/(inRect.size.width-1.), localCoords.y/(inRect.size.height-1.) );
}
static inline GPoint PixelForNormCoordsInRect(GPoint inPoint, GRect inRect)	{
	return MakePoint( (inPoint.x*(inRect.size.width-1.))+inRect.origin.x, (inPoint.y*(inRect.size.height-1.))+inRect.origin.y );
}




static inline GPoint CarToPol(GPoint inPoint)	{
	float		radians = sqrt(pow(inPoint.x, 2) + pow(inPoint.y, 2));
	float		degrees = RAD2DEG * atan(inPoint.y / inPoint.x);
	
	if (inPoint.x < 0.)	{
		degrees += 180.;
	}
	else if (inPoint.x >= 0. && inPoint.y < 0.)	{
		degrees += 360;
	}
	
	while (degrees < 0.)	{
		degrees += 360.;
	}
	while (degrees >= 360.)	{
		degrees -= 360.;
	}
	
	GPoint		returnMe = MakePoint(radians, degrees);
	return returnMe;
}
static inline GPoint PolToCar(GPoint inPoint)	{
	return MakePoint( inPoint.x * cos(DEG2RAD * inPoint.y), inPoint.x * sin(DEG2RAD * inPoint.y) );
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




#endif /* SizingToolTypes_h */
