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




//	this struct describes an integer range of values
typedef struct GRange	{
	int32_t		location;	//	if GRangeLocationNotFound, the location was not found
	int32_t		length;
} GRange;

#define GRangeLocationNotFound 0x7FFFFFFF




#endif /* SizingToolTypes_h */
