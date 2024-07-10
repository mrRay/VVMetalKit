#ifndef MSLCompModeSceneShaderTypes_h
#define MSLCompModeSceneShaderTypes_h

#import <simd/simd.h>
#include <VVMetalKit/SizingToolTypes.h>




//	this struct is used to pass the data we need to render to the vertex shader.  you will encode arrays of these (likely in a single buffer) to draw as primitives.
typedef struct	{
	vector_float2		position;	//	location of the vertex in local/orthogonal coords.  only directly used to calculate the homography projection matrix.
	vector_float2		texCoord;	//	tex coords (in pixels) to sample at this vertex.
	
	uint16_t		layerIndex;	//	the index of the MSLCompModeLayer struct that contains all of the info about the layer that "owns" this vertex.
} MSLCompModeQuadVertex;


//	an array of instances of this struct is passed to the shaders via a single buffer
typedef struct	{
	matrix_float4x4		texToGeoTrans;	//	transforms local texture srcRect coords to occupy
	float				opacity;	//	the opacity to be applied to the image in 'srcRect'.  okay to modify.  basically "layer opacity".
	int8_t				texIndex;	//	which of the textures attached to this shader i should use- populated automatically by this framework, do not modify. -1 means "no texture".
	uint16_t			compModeIndex;	//	which of the comp modes i should use- used to select the function to use that composites color data.  populated automatically by this framework, do not modify.
} MSLCompModeLayer;


//	one instance of this struct is passed to the shaders via a single buffer
typedef struct	{
	vector_float4		canvasRect;	//	x, y, width, height
	int16_t			layerCount;	//	the number of MSLCompModeLayer structs the shader should expect
} MSLCompModeJob;




//	this enumerates the inputs to the vertex shader
typedef enum MSLCompModeSceneA_VS_Index	{
	MSLCompModeSceneA_VS_Index_Verts = 0,	//	MSLCompModeQuadVertex *
	MSLCompModeSceneA_VS_Index_MVPMatrix,	//	float4x4 *
	MSLCompModeSceneA_VS_Index_Layers,	//	MSLCompModeLayer *
} MSLCompModeSceneA_VS_Index;


typedef enum MSLCompModeSceneA_FS_Index	{
	MSLCompModeSceneA_FS_Index_Layers = 0,	//	MSLCompModeLayer *
	MSLCompModeSceneA_FS_Index_Textures,	//	MSLCompModeSceneTexture *
	MSLCompModeSceneA_FS_Index_Job	//	MSLCompModeJob *
} MSLCompModeSceneA_FS_Index;






#endif /* MSLCompModeSceneShaderTypes_h */
