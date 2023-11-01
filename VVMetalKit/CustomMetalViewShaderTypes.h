//
//  CustomMetalViewShaderTypes.h
//  VVMetalKit
//
//  Created by testadmin on 5/10/23.
//

#ifndef CustomMetalViewShaderTypes_h
#define CustomMetalViewShaderTypes_h




typedef enum CMV_VS_Idx	{
	CMV_VS_IDX_Verts = 0,
	CMV_VS_IDX_MVP
} CMV_VS_IDX;




typedef enum CMV_FS_Idx	{
	CMV_FS_Idx_Tex = 0
} CMV_FS_Idx;




typedef struct	{
	vector_float4		color;
	vector_float2		position;
	//	non-normalized texture coordinates
	vector_float2		texCoord;
	//	this struct is used for both simple 2d textures and 2d texture arrays- if the texIndex is < 0, don't draw/sample the texture.  if it's >= 0, either use the only available texture or it's the value of the slice in the texture array to use.
	int8_t				texIndex;
} CMVSimpleVertex;




#endif /* CustomMetalViewShaderTypes_h */
