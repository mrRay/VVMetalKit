#ifndef MSLCompModeSceneAShaderTypes_h
#define MSLCompModeSceneAShaderTypes_h

#include "MSLCompModeSceneShaderTypes.h"


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






#endif /* MSLCompModeSceneAShaderTypes_h */
