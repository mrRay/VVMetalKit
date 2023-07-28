float4 CompositeTopAndBottom(thread float4 & bottom, thread float4 & top, thread float & topAlpha, thread MSLCompModeFragData & fragData)
{
	float4		darkenedBottom = float4(bottom.a) * bottom;
	darkenedBottom.a = bottom.a;
	float4		returnMe;
	
	returnMe.r = (darkenedBottom.r == 1.0)
		? darkenedBottom.r
		: min((top.r * top.r / (1.0 - darkenedBottom.r)), 1.0);
	returnMe.g = (darkenedBottom.g == 1.0)
		? darkenedBottom.g
		: min((top.g * top.g / (1.0 - darkenedBottom.g)), 1.0);
	returnMe.b = (darkenedBottom.b == 1.0)
		? darkenedBottom.b
		: min((top.b * top.b / (1.0 - darkenedBottom.b)), 1.0);
	
	//returnMe.a = (darkenedBottom.a == 1.0)
	//	? darkenedBottom.a
	//	: min((top.a * top.a / (1.0 - darkenedBottom.a)), 1.0);
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
