#include <metal_stdlib>
using namespace metal;

#include "PreviewViewShaderTypes.h"
#include "SizingTool_metal.h"




typedef struct	{
	float4			position [[ position ]];
} PreviewViewRasterizerData;




vertex PreviewViewRasterizerData PreviewViewVertShader(
	uint vertexID [[ vertex_id ]],
	constant PreviewViewVertex * inVerts [[ buffer(PV_VS_Index_Verts) ]],
	constant float4x4 * inMVP [[ buffer(PV_VS_Index_MVPMatrix) ]])
{
	PreviewViewRasterizerData		returnMe;
	
	float4x4			mvp = float4x4(*inMVP);
	float4				pos = float4(inVerts[vertexID].position, 0, 1);
	returnMe.position = mvp * pos;
	
	return returnMe;
}




fragment float4 PreviewViewFragShader(
	PreviewViewRasterizerData inRasterData [[ stage_in ]],
	texture2d<float, access::sample> tex [[ texture(PV_FS_Index_Color) ]],
	constant MTLImgBufferStruct * displayInfo [[ buffer(PV_FS_Index_Geo) ]])
{
	
	//	the bounds we need to size the texture to fit within- calculated by PreviewView using RectThatFitsRectInRect(), 
	//	so the AR is guaranteed to match the AR of the image we want to display in it!
	GRect			dstRect = displayInfo->dstRect;
	
	//	this is the texel we're currently evaluating...
	GPoint			thisTexel = MakePoint(inRasterData.position.x, inRasterData.position.y);
	//GPoint			thisTexelNorm = NormCoordsOfPointInRect(thisTexel, dstRect);
	GPoint			thisTexelNorm = NormCoordsOfPixelInRect(thisTexel, dstRect);
	
	//	if this texel doesn't lie within the area the image is to be displayed in, return transparent black
	if (!PointInRect(thisTexel, dstRect))	{
		return float4(0,0,0,0);
	}
	
	//	get the src rect we're supposed to be drawing
	GRect			srcRect = displayInfo->srcRect;
	
	float2			samplerCoord;
	if (displayInfo->flipped)	{
		samplerCoord = float2(
			(thisTexelNorm.x * (srcRect.size.width-1)) + srcRect.origin.x,
			((1.0-thisTexelNorm.y) * (srcRect.size.height-1)) + srcRect.origin.y
		);
	}
	else	{
		samplerCoord = float2(
			(thisTexelNorm.x * (srcRect.size.width-1)) + srcRect.origin.x,
			(thisTexelNorm.y * (srcRect.size.height-1)) + srcRect.origin.y
		);
	}
	
	
	
	//	calculate the coords of the image we want to fetch
	////float2			normPosInImageBounds = NormCoordsOfPointInRect(thisTexel, dstRect);
	//float2			normPosInImageBounds = NormCoordsOfPixelInRect(thisTexel, dstRect);
	//float2			contentCoordsInImageBounds;
	//
	//contentCoordsInImageBounds.x = (normPosInImageBounds.x * srcRect.size.width) + srcRect.origin.x;
	//contentCoordsInImageBounds.y = (normPosInImageBounds.y * srcRect.size.height) + srcRect.origin.y;
	
	//float2			samplerCoord = float2( contentCoordsInImageBounds.x/srcRect.size.width, contentCoordsInImageBounds.y/srcRect.size.height );
	
	constexpr sampler		sampler(mag_filter::linear, min_filter::linear, address::clamp_to_edge, coord::pixel);
	float4			color = tex.sample(sampler, samplerCoord);
	return color;
	
}


