#ifndef SizingTool_c_h
#define SizingTool_c_h

#include <stdio.h>
#include <stdbool.h>
#include <VVMetalKit/SizingToolTypes.h>




GPoint MakePoint(float inX, float inY);
bool GPointsEqual(GPoint inA, GPoint inB);

GSize MakeSize(float inWidth, float inHeight);
bool GSizesEqual(GSize inA, GSize inB);

GRect MakeRect(float inX, float inY, float inW, float inH);
GRect MakeRectFromVals(GPoint inPt, GSize inSize);
bool GRectsEqual(GRect inA, GRect inB);

GRect RectThatFitsRectInRect(GRect inSrcRect, GRect inDstRect, SizingMode mode);

bool PointInRect(GPoint inPoint, GRect inRect);

float MaxX(GRect inRect);
float MinX(GRect inRect);
float MaxY(GRect inRect);
float MinY(GRect inRect);

GPoint NormCoordsOfPointInRect(GPoint inPoint, GRect inRect);

GPoint NormCoordsOfPixelInRect(GPoint inPoint, GRect inRect);
GPoint PixelForNormCoordsInRect(GPoint inPoint, GRect inRect);




#endif /* SizingTool_c_h */
