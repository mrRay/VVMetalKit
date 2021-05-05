#include <metal_stdlib>
using namespace metal;

#include "SizingTool_metal.h"




GPoint MakePoint(float inX, float inY)	{
	return { inX, inY };
}
bool GPointsEqual(GPoint inA, GPoint inB)	{
	return (inA.x == inB.x && inA.y == inB.y);
}


GSize MakeSize(float inWidth, float inHeight)	{
	return { inWidth, inHeight };
}
bool GSizesEqual(GSize inA, GSize inB)	{
	return (inA.width == inB.width && inA.height == inB.height);
}


GRect MakeRect(float inX, float inY, float inW, float inH)	{
	return { { inX, inY }, { inW, inH } };
}
GRect MakeRect(GPoint inPt, GSize inSize)	{
	return { inPt, inSize };
}
bool GRectsEqual(GRect inA, GRect inB)	{
	return (GPointsEqual(inA.origin, inB.origin) && GSizesEqual(inA.size, inB.size));
}




GRect RectThatFitsRectInRect(GRect a, GRect b, SizingMode m)	{
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
		returnMe.size = { round(a.size.width), round(a.size.height) };
		returnMe.origin.x = round((b.size.width-returnMe.size.width)/2.0+b.origin.x);
		returnMe.origin.y = round((b.size.height-returnMe.size.height)/2.0+b.origin.y);
		break;
	}
	return returnMe;
	
	
	//return float4(0,0,0,0);
	//return MakeRect(0., 0., 0., 0.);
}


//bool PointInRect(thread GPoint & inPoint, thread GRect & inRect)	{
//	if (inPoint.x < MinX(inRect) || inPoint.x > MaxX(inRect))
//		return false;
//	if (inPoint.y < MinY(inRect) || inPoint.y > MaxY(inRect))
//		return false;
//	return true;
//}
bool PointInRect(GPoint inPoint, GRect inRect)	{
	if (inPoint.x < MinX(inRect) || inPoint.x > MaxX(inRect))
		return false;
	if (inPoint.y < MinY(inRect) || inPoint.y > MaxY(inRect))
		return false;
	return true;
}


float MaxX(thread GRect & inRect)	{
	if (inRect.size.width > 0.)
		return inRect.origin.x + inRect.size.width;
	else
		return inRect.origin.x;
}
float MinX(thread GRect & inRect)	{
	if (inRect.size.width > 0.)
		return inRect.origin.x;
	else
		return inRect.origin.x + inRect.size.width;
}
float MaxY(thread GRect & inRect)	{
	if (inRect.size.height > 0.)
		return inRect.origin.y + inRect.size.height;
	else
		return inRect.origin.y;
}
float MinY(thread GRect & inRect)	{
	if (inRect.size.height > 0.)
		return inRect.origin.y;
	else
		return inRect.origin.y + inRect.size.height;
}


GPoint NormCoordsOfPointInRect(thread GPoint & inPoint, thread GRect & inRect)	{
	GPoint		localCoords = MakePoint(inPoint.x - inRect.origin.x, inPoint.y - inRect.origin.y);
	return MakePoint( localCoords.x/inRect.size.width, localCoords.y/inRect.size.height );
	//float2		localCoords = float2(inPoint.x - inRect.origin.x, inPoint.y - inRect.origin.y);
	//return float2( localCoords.x/inRect.size.width, localCoords.y/inRect.size.height );
}


