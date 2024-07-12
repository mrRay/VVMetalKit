#ifndef MSLCompModeSceneBShaderTypes_h
#define MSLCompModeSceneBShaderTypes_h

#include "MSLCompModeSceneShaderTypes.h"


//	this enumerates the inputs to the vertex shader
typedef enum MSLCompModeSceneB_VS_Index	{
	MSLCompModeSceneB_VS_Index_Verts = 0,	//	MSLCompModeQuadVertex *
	MSLCompModeSceneB_VS_Index_MVPMatrix,	//	float4x4 *
} MSLCompModeSceneB_VS_Index;



typedef enum MSLCompModeSceneB_FS_Index	{
	MSLCompModeSceneB_FS_Index_Layers = 0,	//	MSLCompModeLayer *
	MSLCompModeSceneB_FS_Index_Textures,	//	MSLCompModeSceneTexture *
	MSLCompModeSceneB_FS_Index_Job	//	MSLCompModeJob *
} MSLCompModeSceneB_FS_Index;





#endif /* MSLCompModeSceneBShaderTypes_h */
