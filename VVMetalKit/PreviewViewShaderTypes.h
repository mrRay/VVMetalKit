#ifndef PreviewViewShaderTypes_h
#define PreviewViewShaderTypes_h

#include <VVMetalKit/SizingToolTypes.h>
#include <VVMetalKit/MTLImgBufferShaderTypes.h>




typedef enum PV_VS_Index	{
	PV_VS_Index_Verts = 0,
	PV_VS_Index_MVPMatrix
} PV_VS_Index;




typedef enum PV_FS_Index	{
	PV_FS_Index_Color = 0,	//	texture to be displayed
	PV_FS_Index_Geo	//	MTLImgBufferStruct describing how/where to draw the texture (there are four of these structs at this index)
} PV_FS_Index;




typedef struct	{
	vector_float2		position;
} PreviewViewVertex;




#endif /* PreviewViewShaderTypes_h */
