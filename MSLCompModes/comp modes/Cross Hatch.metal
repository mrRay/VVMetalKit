//	adapted from http://transitions.glsl.io/transition/04fd9a7de4012cbb03f6

const constant float2 center = float2(0.5, 0.5);

float quadraticInOut(float t) {
	float p = 2.0 * t * t;
	return t < 0.5 ? p : -p + (4.0 * t) - 1.0;
}

// borrowed from wind.
// https://glsl.io/transition/7de3f4b9482d2b0bf7bb
float CrossHatchRand(float2 co) {
	return fract(sin(dot(co.xy ,float2(12.9898,78.233))) * 43758.5453);
}


float4 CompositeTopAndBottom(thread float4 & bottom, thread float4 & top, thread float & topAlpha, thread MSLCompModeFragData & fragData)
{
	float2		p = fragData.gl_FragCoord.xy / fragData._VVCanvasRect.zw;
	float4		darkenedBottom = float4(bottom.a) * bottom;
	darkenedBottom.a = bottom.a;
	float4		returnMe = darkenedBottom;
    float		x = topAlpha * 1.72;
    float		dist = distance(center, p);
    float		r = x - min(CrossHatchRand(float2(p.y, 0.0)), CrossHatchRand(float2(0.0, p.x)));
    float		m = dist <= r ? 1.0 : 0.0;
    
    returnMe = mix(darkenedBottom, top, m);  
	return returnMe;
}


float4 CompositeBottom(thread float4 & bottom, thread float & bottomAlpha, thread MSLCompModeFragData & fragData)	{
	float2		p = fragData.gl_FragCoord.xy / fragData._VVCanvasRect.zw;
	float4		darkenedBottom = float4(0.0);
	float4		returnMe = darkenedBottom;
    float		x = bottomAlpha * 1.72;
    float		dist = distance(center, p);
    float		r = x - min(CrossHatchRand(float2(p.y, 0.0)), CrossHatchRand(float2(0.0, p.x)));
    float		m = dist <= r ? 1.0 : 0.0;
    
    returnMe = mix(darkenedBottom, bottom, m);  
	return returnMe;
}
//vec4 CompositeTop(vec4 top, float topAlpha)	{
//	return vec4(0.0, 0.0, 0.0, 0.0);
//}
