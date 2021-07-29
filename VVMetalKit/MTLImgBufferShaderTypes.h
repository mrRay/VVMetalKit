#ifndef MTLImgBufferShaderTypes_h
#define MTLImgBufferShaderTypes_h

#include <VVMetalKit/SizingToolTypes.h>




typedef struct MTLImgBufferStruct	{
	GRect			srcRect;	//	the region of the passed texture that contains the image we want to work with
	GRect			dstRect;	//	the rect at which 'srcRect' should be drawn, in whatever context it is being drawn
} MTLImgBufferStruct;




#endif /* MTLImgBufferShaderTypes_h */
