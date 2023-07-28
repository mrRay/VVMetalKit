//	adapted from http://transitions.glsl.io/transition/ce1d48f0ce00bb379750


#define PI 3.141592653589


float4 CompositeTopAndBottom(thread float4 & bottom, thread float4 & top, thread float & topAlpha, thread MSLCompModeFragData & fragData)
{
	float2		p = fragData.gl_FragCoord.xy / fragData._VVCanvasRect.zw;
	float4		darkenedBottom = float4(bottom.a) * bottom;
	darkenedBottom.a = bottom.a;
	float4		returnMe = darkenedBottom;

	float2		rp = p*2.-1.;
	float		a = atan2(rp.y, rp.x);
	float		pa = topAlpha*PI*2.25-PI*1.25;
	float4		fromc = darkenedBottom;
	float4		toc = top;
	
	if(a>pa) {
		returnMe = mix(toc, fromc, smoothstep(0., 1., (a-pa)));
	} else {
		returnMe = toc;
	}
	
	return returnMe;
}

float4 CompositeBottom(thread float4 & bottom, thread float & bottomAlpha, thread MSLCompModeFragData & fragData)	{
	float2		p = fragData.gl_FragCoord.xy / fragData._VVCanvasRect.zw;
	float4		darkenedBottom = float4(0.0);
	float4		returnMe = darkenedBottom;

	float2		rp = p*2.-1.;
	float		a = atan2(rp.y, rp.x);
	float		pa = bottomAlpha*PI*2.25-PI*1.25;
	float4		fromc = darkenedBottom;
	float4		toc = bottom;
	
	if(a>pa) {
		returnMe = mix(toc, fromc, smoothstep(0., 1., (a-pa)));
	} else {
		returnMe = toc;
	}
	
	return returnMe;
}

//vec4 CompositeTop(vec4 top, float topAlpha)	{
//	return vec4(0.0, 0.0, 0.0, 0.0);
//}
