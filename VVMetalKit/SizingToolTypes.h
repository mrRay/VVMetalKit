#ifndef SizingToolTypes_h
#define SizingToolTypes_h




typedef enum SizingMode	{
	SizingModeFit = 0,
	SizingModeFitWidth,
	SizingModeFill,
	SizingModeStretch,
	SizingModeCopy
} SizingMode;




typedef struct GSize	{
	float		width;
	float		height;
} GSize;




typedef struct GPoint	{
	float		x;
	float		y;
} GPoint;




typedef struct GRect	{
	GPoint			origin;
	GSize			size;
} GRect;




#endif /* SizingToolTypes_h */
