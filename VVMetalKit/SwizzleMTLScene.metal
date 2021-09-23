#include <metal_stdlib>
#include "SwizzleMTLSceneTypes.h"

using namespace metal;


kernel void SwizzleMTLSceneFunc(
	texture2d<float,access::read> inputTex [[ texture(SwizzleShaderArg_SrcImg) ]],
	texture2d<float,access::read> outputTex [[ texture(SwizzleShaderArg_DstImg) ]],
	constant SwizzleShaderInfo * info [[ buffer(SwizzleShaderArg_Info) ]],
	uint2 gid [[ thread_position_in_grid ]])
{
}


