float4 CompositeTopAndBottom(thread float4 & bottom, thread float4 & top, thread float & topAlpha, thread MSLCompModeFragData & fragData)
{
	float4		darkenedBottom = float4(bottom.a) * bottom;
	darkenedBottom.a = bottom.a;
	float4		darkenedTop = float4(topAlpha) * top;
	const float4 	lumacoeff = float4(0.2126, 0.7152, 0.0722, 0.0);
	float		fgLuminosity = dot(darkenedTop, lumacoeff);
	float		bgLuminosity = dot(darkenedBottom, lumacoeff);
	float4		returnMe;
	returnMe.r = (fgLuminosity > bgLuminosity)
		? top.r
		: darkenedBottom.r;
	returnMe.g = (fgLuminosity > bgLuminosity)
		? top.g
		: darkenedBottom.g;
	returnMe.b = (fgLuminosity > bgLuminosity)
		? top.b
		: darkenedBottom.b;
	
	returnMe.a = top.a;
	returnMe = mix(darkenedBottom, returnMe, topAlpha*top.a);
	return returnMe;
}


float4 CompositeBottom(thread float4 & bottom, thread float & bottomAlpha, thread MSLCompModeFragData & fragData)	{
	float4		returnMe = float4(bottomAlpha)*bottom;
	returnMe.a = 1.0;
	return returnMe;
}
//vec4 CompositeTop(vec4 top, float topAlpha)	{
//	vec4		returnMe = vec4(topAlpha)*top;
//	returnMe.a = 1.0;
//	return returnMe;
//}
