
float4 CompositeTopAndBottom(device float4 & bottom, device float4 & top, device float & topAlpha)	{
	//	assume the color to be the color of the top pixel...
	
	//	if the top pixel is transparent, something may be visible "through" it
	float		TTO = top.a*topAlpha;	//	"total top opacity". 1.0 is "fully opaque".
	//	the less opaque the top, the more the bottom should "show through"- unless the bottom is transparent!
	float		TBO = bottom.a*bottomAlpha;	//	"total bottom opacity".  1.0 is "fully opaque".
	
	//	...so use TBO to calculate the "real bottom color"...
	float4		realBottom = mix(bottom,top,(1.0-TBO));
	//	...then use TTO to calculate how much this shows through the top color...
	float4		realTop = mix(realBottom, top, TTO);
	
	
	float4		returnMe = realTop;
	//returnMe.a = 1.0;
	//returnMe.a = (top.a*topAlpha) + (bottom.a*(1.0-topAlpha));
	returnMe.a = (TTO) + (bottom.a * (1.0-TTO));
	return returnMe;
}

float4 CompositeBottom(device float4 & bottom, device float & bottomAlpha)	{
	return float4(bottom.r, bottom.g, bottom.b, bottom.a*bottomAlpha);
}
