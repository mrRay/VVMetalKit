#ifndef SizingTool_h
#define SizingTool_h

#include <VVMetalKit/SizingToolTypes.h>



GPoint MakePoint(float inX, float inY);
bool GPointsEqual(GPoint inA, GPoint inB);

GSize MakeSize(float inWidth, float inHeight);
bool GSizesEqual(GSize inA, GSize inB);

GRect MakeRect(float inX, float inY, float inW, float inH);
GRect MakeRect(GPoint inPt, GSize inSize);
bool GRectsEqual(GRect inA, GRect inB);

GRect RectThatFitsRectInRect(GRect inSrcRect, GRect inDstRect, SizingMode mode);

bool PointInRect(GPoint inPoint, GRect inRect);

float MaxX(thread GRect & inRect);
float MinX(thread GRect & inRect);
float MaxY(thread GRect & inRect);
float MinY(thread GRect & inRect);

GPoint NormCoordsOfPointInRect(thread GPoint & inPoint, thread GRect & inRect);




#endif /* SizingTool_h */
