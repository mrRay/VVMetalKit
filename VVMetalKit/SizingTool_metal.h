#ifndef SizingTool_h
#define SizingTool_h

#include <VVMetalKit/SizingToolTypes.h>



#ifdef __METAL_VERSION__


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
GPoint PointForNormCoordsInRect(thread GPoint & inPoint, thread GRect & inRect);

//GPoint NormCoordsOfPixelInRect(thread GPoint & inPoint, thread GRect & inRect);
GPoint NormCoordsOfPixelInRect(GPoint inPoint, GRect inRect);

//GPoint PixelForNormCoordsInRect(thread GPoint & inPoint, thread GRect & inRect);
GPoint PixelForNormCoordsInRect(GPoint inPoint, GRect inRect);


GRange MakeGRange(int32_t inLocation, int32_t inLength);
GRange MakeGRangeAbsolute(GRange inRange);
GRange InvertGRangeLength(GRange inRange);


#endif




#endif /* SizingTool_h */
