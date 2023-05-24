
float4 CompositeTopAndBottom(device float4 & bottom, device float4 & top, device float & topAlpha)	{
	float4		DB = float4(bottom.a)*bottom;
	DB.a = bottom.a;
	float		TA = top.a*topAlpha;
	float4		DT = float4(TA) * top;
	DT.a = TA;
	float4		returnMe = abs(DT-DB);
	returnMe.a = 1.0;
	return returnMe;
}

float4 CompositeBottom(device float4 & bottom, device float & bottomAlpha)	{
	return float4(bottom.r, bottom.g, bottom.b, bottom.a*bottomAlpha);
}
