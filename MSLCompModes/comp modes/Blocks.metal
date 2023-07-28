//	adapted from http://transitions.glsl.io/transition/b93818de23d4511fde10


const constant float		blockSize = 20.0;

float BlocksRand(float2 co) {
    return fract(sin(dot(co, float2(12.9898, 78.233))) * 43758.5453);
}


float4 CompositeTopAndBottom(thread float4 & bottom, thread float4 & top, thread float & topAlpha, thread MSLCompModeFragData & fragData)
{
	//float2		p = gl_FragCoord.xy / _VVCanvasRect.zw;
	float4		darkenedBottom = float4(bottom.a) * bottom;
	darkenedBottom.a = bottom.a;
	float4		returnMe = float4(0.0);

	returnMe = mix(darkenedBottom, top, step(BlocksRand(floor(fragData.gl_FragCoord.xy/blockSize)), topAlpha));
	return returnMe;
}

float4 CompositeBottom(thread float4 & bottom, thread float & bottomAlpha, thread MSLCompModeFragData & fragData)
{
	float4		returnMe = float4(0.0);
	float		randVal = BlocksRand(floor(fragData.gl_FragCoord.xy/blockSize));
	float		mixAmt = step(randVal, bottomAlpha);
	returnMe = mix(returnMe, bottom, mixAmt );
	return returnMe;
}

//vec4 CompositeTop(vec4 top, float topAlpha)	{
//	return vec4(0.0, 0.0, 0.0, 0.0);
//}
