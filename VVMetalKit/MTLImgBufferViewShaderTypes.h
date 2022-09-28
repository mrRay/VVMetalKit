#ifndef PreviewViewShaderTypes_h
#define PreviewViewShaderTypes_h

//#include <VVMetalKit/SizingToolTypes.h>
//#include <VVMetalKit/MTLImgBufferShaderTypes.h>
#import <TargetConditionals.h>
#if TARGET_OS_IOS
#include <VVMetalKitTouch/SizingToolTypes.h>
#include <VVMetalKitTouch/MTLImgBufferShaderTypes.h>
#else
#include <VVMetalKit/SizingToolTypes.h>
#include <VVMetalKit/MTLImgBufferShaderTypes.h>
#endif
//#include "SizingToolTypes.h"
//#include "MTLImgBufferShaderTypes.h"




typedef enum MTLImgBufferView_VS_Index	{
	MTLImgBufferView_VS_Index_Verts = 0,	//	geometry data formatted as 'MTLImgBufferViewVertex'
	MTLImgBufferView_VS_Index_MVPMatrix		//	a 4x4 matrix describing the (concatenated) model/view/projection matrix
} MTLImgBufferView_VS_Index;




typedef enum MTLImgBufferView_FS_Index	{
	MTLImgBufferView_FS_Index_Color = 0,	//	texture to be displayed
	MTLImgBufferView_FS_Index_Geo	//	MTLImgBufferStruct describing how/where to draw the texture (there are four of these structs at this index)
} MTLImgBufferView_FS_Index;




typedef struct	{
	vector_float2		position;
} MTLImgBufferViewVertex;




#endif /* PreviewViewShaderTypes_h */
