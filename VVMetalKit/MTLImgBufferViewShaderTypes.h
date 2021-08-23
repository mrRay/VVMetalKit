#ifndef PreviewViewShaderTypes_h
#define PreviewViewShaderTypes_h

#include <VVMetalKit/SizingToolTypes.h>
#include <VVMetalKit/MTLImgBufferShaderTypes.h>




typedef enum MTLImgBufferView_VS_Index	{
	MTLImgBufferView_VS_Index_Verts = 0,
	MTLImgBufferView_VS_Index_MVPMatrix
} MTLImgBufferView_VS_Index;




typedef enum MTLImgBufferView_FS_Index	{
	MTLImgBufferView_FS_Index_Color = 0,	//	texture to be displayed
	MTLImgBufferView_FS_Index_Geo	//	MTLImgBufferStruct describing how/where to draw the texture (there are four of these structs at this index)
} MTLImgBufferView_FS_Index;




typedef struct	{
	vector_float2		position;
} MTLImgBufferViewVertex;




#endif /* PreviewViewShaderTypes_h */
