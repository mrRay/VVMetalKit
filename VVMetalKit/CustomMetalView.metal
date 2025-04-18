//
//  CustomMetalView.metal
//  VVMetalKit
//
//  Created by testadmin on 11/1/23.
//

#include <metal_stdlib>
using namespace metal;

#include "CustomMetalViewShaderTypes.h"




typedef struct	{
	float4			position [[ position ]];
	
	vector_float4	color;
	vector_float2	texCoord;
	int8_t			texIndex;
} CustomMetalViewRasterizerData;

typedef struct	{
	texture2d<float,access::sample>		texture;	//	has an implicit id of 0
} CustomMetalViewTexture;




vertex CustomMetalViewRasterizerData CustomMetalViewVertShader(
	uint vertexID [[ vertex_id ]],
	//uint instanceID [[ instance_id ]],
	//uint baseVertex [[ base_vertex ]],
	//uint baseInstance [[ base_instance ]],
	constant CMVSimpleVertex * inVerts [[ buffer(CMV_VS_IDX_Verts) ]],
	constant float4x4 * inMVP [[ buffer(CMV_VS_IDX_MVP) ]]
	)
{
	CustomMetalViewRasterizerData		returnMe;
	
	//constant CMVSimpleVertex		*rPtr = inVerts + vertexID + (4 * instanceID);
	constant CMVSimpleVertex		*rPtr = inVerts + vertexID;
	float4			pos = float4(rPtr->position.xy, 0, 1);
	
	float4x4		mvp = float4x4(*inMVP);
	returnMe.position = mvp * pos;
	//returnMe.position = (*mvp) * pos;
	
	returnMe.color = rPtr->color;
	returnMe.texCoord = rPtr->texCoord;
	returnMe.texIndex = rPtr->texIndex;
	
	return returnMe;
}




fragment float4 CustomMetalViewFragShader(
	CustomMetalViewRasterizerData inRasterData [[ stage_in ]],
	//texture2d<float,access::sample> inTex [[ texture(CMV_FS_Idx_Tex) ]]
	device CustomMetalViewTexture * inTextures [[ buffer(CMV_FS_Idx_Tex) ]]
	//float4 baseCanvasColor [[ color(0) ]]
	)
{
	float4			newFragColor;
	
	if (inRasterData.texIndex < 0)	{
		newFragColor = inRasterData.color;
	}
	else	{
		device CustomMetalViewTexture		*texStructPtr = inTextures + inRasterData.texIndex;
		
		float2			samplerCoord = inRasterData.texCoord;
		constexpr sampler		sampler(mag_filter::linear, min_filter::linear, address::clamp_to_edge, coord::pixel);
		float4		samplerColor = texStructPtr->texture.sample(sampler, samplerCoord);
		
		//newFragColor = inRasterData.color * texStructPtr->texture.sample(sampler, samplerCoord);
		newFragColor = inRasterData.color * float4(samplerColor.r, samplerColor.g, samplerColor.b, 1.) * float4(samplerColor.a, samplerColor.a, samplerColor.a, samplerColor.a);
	}
	
	if (newFragColor.a >= 1.)
		return newFragColor;
	
	//return mix(baseCanvasColor, newFragColor, newFragColor.a);
	return newFragColor;
}





fragment float4 CustomMetalViewFragShaderIgnoreSampledAlpha(
	CustomMetalViewRasterizerData inRasterData [[ stage_in ]],
	//texture2d<float,access::sample> inTex [[ texture(CMV_FS_Idx_Tex) ]]
	device CustomMetalViewTexture * inTextures [[ buffer(CMV_FS_Idx_Tex) ]]
	//float4 baseCanvasColor [[ color(0) ]]
	)
{
	float4			newFragColor;
	
	if (inRasterData.texIndex < 0)	{
		newFragColor = inRasterData.color;
	}
	else	{
		device CustomMetalViewTexture		*texStructPtr = inTextures + inRasterData.texIndex;
		
		float2			samplerCoord = inRasterData.texCoord;
		constexpr sampler		sampler(mag_filter::linear, min_filter::linear, address::clamp_to_edge, coord::pixel);
		float4		samplerColor = texStructPtr->texture.sample(sampler, samplerCoord);
		
		//newFragColor = inRasterData.color * texStructPtr->texture.sample(sampler, samplerCoord);
		newFragColor = inRasterData.color * float4(samplerColor.r, samplerColor.g, samplerColor.b, 1.) * float4(samplerColor.a, samplerColor.a, samplerColor.a, samplerColor.a);
		newFragColor.a = 1.0;
	}
	
	if (newFragColor.a >= 1.)
		return newFragColor;
	
	//return mix(baseCanvasColor, newFragColor, newFragColor.a);
	return newFragColor;
}


