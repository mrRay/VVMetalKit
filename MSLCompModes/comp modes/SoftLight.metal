float4 CompositeTopAndBottom(thread float4 & bottom, thread float4 & top, thread float & topAlpha, thread MSLCompModeFragData & fragData)
{
	float4		darkenedBottom = float4(bottom.a) * bottom;
	darkenedBottom.a = bottom.a;
	float4		returnMe;
	
	returnMe.r = (top.r > 0.5)
		? (1.0 - (1.0 - darkenedBottom.r) * (1.0 - (top.r - 0.5)))
		: (darkenedBottom.r * (top.r + 0.5));
	returnMe.g = (top.g > 0.5)
		? (1.0 - (1.0 - darkenedBottom.g) * (1.0 - (top.g - 0.5)))
		: (darkenedBottom.g * (top.g + 0.5));
	returnMe.b = (top.b > 0.5)
		? (1.0 - (1.0 - darkenedBottom.b) * (1.0 - (top.b - 0.5)))
		: (darkenedBottom.b * (top.b + 0.5));
	
	returnMe.a = (top.a > 0.5)
		? (1.0 - (1.0 - darkenedBottom.a) * (1.0 - (top.a - 0.5)))
		: (darkenedBottom.a * (top.a + 0.5));
	
	//returnMe.a = top.a * topAlpha;
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
