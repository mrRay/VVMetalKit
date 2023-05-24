
float4 CompositeTopAndBottom(device float4 & bottom, device float4 & top, device float & topAlpha)	{
	float4		DB = float4(bottom.a)*bottom;
	DB.a = bottom.a;
	float		TA = top.a*topAlpha;
	float4		DT = float4(TA) * top;
	DT.a = TA;
	float4		returnMe = DT+DB;
	returnMe.r = (returnMe.r > 1.0) ? (returnMe.r - 1.0) : returnMe.r;
	returnMe.g = (returnMe.g > 1.0) ? (returnMe.g - 1.0) : returnMe.g;
	returnMe.b = (returnMe.b > 1.0) ? (returnMe.b - 1.0) : returnMe.b;
	//returnMe.a = (returnMe.a > 1.0) ? (returnMe.a - 1.0) : returnMe.a;
	returnMe.a = 1.0;
	return returnMe;
}

float4 CompositeBottom(device float4 & bottom, device float & bottomAlpha)	{
	return float4(bottom.r, bottom.g, bottom.b, bottom.a*bottomAlpha);
}
