#ifndef MSLCompModeSceneShaderTypes_h
#define MSLCompModeSceneShaderTypes_h

#import <simd/simd.h>
#import <VVMetalKit/SizingToolTypes.h>


//	this struct is used to pass the data we need to render to the vertex shader
typedef struct	{
	vector_float2		position;	//	location of the vertex in local/orthogonal coords.  only directly used to calculate the homography projection matrix.
	vector_float2		texCoord;	//	tex coords (in pixels) to sample at this vertex.
	
	float				opacity;	//	the opacity to be applied to the image in 'srcRect'.  okay to modify.  basically "layer opacity".
	int8_t				texIndex;	//	which of the textures attached to this shader i should use- populated automatically by this framework, do not modify
	uint16_t			compModeIndex;	//	which of the comp modes i should use- used to select the function to use that composites color data.  populated automatically by this framework, do not modify.
} MSLCompModeQuadVertex;


//	this enumerates the inputs to the vertex shader
typedef enum MSLCompModeScene_VS_Index	{
	MSLCompModeScene_VS_Index_Verts = 0,
	MSLCompModeScene_VS_Index_MVPMatrix,
	MSLCompModeScene_VS_Index_Homography
} MSLCompModeScene_VS_Index;


#endif /* MSLCompModeSceneShaderTypes_h */
