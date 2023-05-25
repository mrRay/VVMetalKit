#ifndef MSLCompModeSceneShaderTypes_h
#define MSLCompModeSceneShaderTypes_h

#import <simd/simd.h>
#import <VVMetalKit/SizingToolTypes.h>


//	this struct is used to pass the data we need to render to the vertex shader
typedef struct	{
	vector_float2		position;	//	location of the vertex in local/orthogonal coords
	vector_float2		texCoord;	//	tex coords, normalized in both dimensions (x and y both run 0-1).  interpolated when passed to frag shader via rasterizer.
	matrix_float4x4		invHomography;	//	transforms fragment coords to the coords of the pixel to sample in my source texture.  inverse of the transform required to distort the image's rect to occupy the quad seen onscreen.
	
	GRect				srcRect;	//	TOP LEFT CORNER IS ORIGIN. describes the rectangular region in the source texture that is to be displayed within this quad
	bool				flipH;	//	whether or not the image in 'srcRect' is flipped horizontally and needs to be un-flipped to be viewed "correctly"
	bool				flipV;	//	whether or not the image in 'srcRect' is flipped vertically and needs to be un-flipped to be viewed "correctly"
	
	float				opacity;	//	the opacity to be applied to the image in 'srcRect'
	int8_t				texIndex;	//	which of the textures attached to this shader i should use
	uint16_t			compModeIndex;	//	which of the comp modes i should use- used to select the function to use that composites color data
} MSLCompModeQuadVertex;


//	this enumerates the inputs to the vertex shader
typedef enum MSLCompModeScene_VS_Index	{
	MSLCompModeScene_VS_Index_Verts = 0,
	MSLCompModeScene_VS_Index_MVPMatrix
} MSLCompModeScene_VS_Index;


#endif /* MSLCompModeSceneShaderTypes_h */
