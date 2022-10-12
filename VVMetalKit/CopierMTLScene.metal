#include <metal_stdlib>
#include "MTLImgBufferShaderTypes.h"
#include "SizingTool_metal.h"

using namespace metal;


kernel void CopierMTLSceneFunc(
	texture2d<float, access::sample> srcTexture [[ texture(0) ]],
	texture2d<float, access::write> outTexture [[ texture(1) ]],
	constant MTLImgBufferStruct * geoBuffer [[ buffer(2) ]],
	uint2 gid [[ thread_position_in_grid ]])
{
	if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height())
		return;
	
	//	if 'gid' is not in geoBuffer's "dstRect" then draw transparent black and we're done immediately
	GPoint		gidPoint = MakePoint(gid.x, gid.y);
	if (!PointInRect(gidPoint, geoBuffer->dstRect))	{
		outTexture.write(float4(0,0,0,0), gid);
		return;
	}
	
	//	calculate the normalized position of "gid" within geoBuffer's "dstRect"
	GRect		dstRect = geoBuffer->dstRect;
	GPoint		normCoords = NormCoordsOfPixelInRect(gidPoint, dstRect);
	if (geoBuffer->flipV)
		normCoords.y = 1.0 - normCoords.y;
	if (geoBuffer->flipH)
		normCoords.x = 1.0 - normCoords.x;
	//	convert this normalized position into pixel coords of the normalized pos within geoBuffer's "srcRect"
	GRect		srcRect = geoBuffer->srcRect;
	GPoint		pxlCoords = PixelForNormCoordsInRect(normCoords, srcRect);
	//	sample srcTexture at these pixel coords
	constexpr sampler		sampler(mag_filter::linear, min_filter::linear, address::clamp_to_edge, coord::pixel);
	const float4			srcColor = srcTexture.sample(sampler, float2(pxlCoords.x,pxlCoords.y)) * geoBuffer->colorMultiplier;
	outTexture.write(srcColor, gid);
	
	
}

