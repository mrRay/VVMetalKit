#include <metal_stdlib>
#include "MTLImgBufferShaderTypes.h"

using namespace metal;


kernel void CopierMTLSceneFunc(
	texture2d<float, access::sample> colorTexture [[ texture(0) ]],
	texture2d<float, access::write> outTexture [[ texture(1) ]],
	constant MTLImgBufferStruct * geoBuffer [[ buffer(2) ]],
	uint2 gid [[ thread_position_in_grid ]])
{
	float2		normLoc = float2( float(gid.x)/geoBuffer->dstRect.size.width, float(gid.y)/geoBuffer->dstRect.size.height );
	float2		readLoc = float2(
		((geoBuffer->srcRect.size.width-1) * normLoc.x) + geoBuffer->srcRect.origin.x,
		((geoBuffer->srcRect.size.height-1) * normLoc.y) + geoBuffer->srcRect.origin.y
	);
	
	constexpr sampler		sampler(mag_filter::linear, min_filter::linear, address::clamp_to_edge, coord::pixel);
	const float4		srcColor = colorTexture.sample(sampler, readLoc);
	outTexture.write(srcColor, gid);
	
	/*
	//	crop reading automatically to the srcRect of the geometry buffer
	uint2		readLoc = uint2(gid.x + geoBuffer->srcRect.origin.x, gid.y + geoBuffer->srcRect.origin.y);
	//	if the readLoc is outside the bounds of the src image's src rect, just write clear alpha
	if (readLoc.x > geoBuffer->srcRect.size.width || readLoc.y > geoBuffer->srcRect.size.height)	{
		outTexture.write( float4(0,0,0,0), gid );
		return;
	}
	
	const float4		srcColor = colorTexture.read(readLoc);
	outTexture.write(srcColor, gid);
	*/
	
	//const float4		srcColor = colorTexture.read(gid);
	//outTexture.write(srcColor, gid);
}

