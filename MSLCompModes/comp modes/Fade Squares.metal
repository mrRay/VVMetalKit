//	based on http://transitions.glsl.io/transition/b6720916aa3f035949bc

//	optional variables
const constant float2 fadeSquareDirection = float2(1.0,0.0);
const constant float2 fadeSquareCenter = float2(0.5, 0.5);
const constant float fadeSquareSmoothness = 2.0;


float4 CompositeTopAndBottom(thread float4 & bottom, thread float4 & top, thread float & topAlpha, thread MSLCompModeFragData & fragData)
{
	float2		p = fragData.gl_FragCoord.xy / fragData._VVCanvasRect.zw;
	float4		darkenedBottom = float4(bottom.a) * bottom;
	darkenedBottom.a = bottom.a;
	float4		returnMe = darkenedBottom;
	float2 		squares = float2(floor(fragData._VVCanvasRect.z / 80.0),floor(fragData._VVCanvasRect.w / 80.0));
	squares.x = (squares.x < 4.0) ? floor(fragData._VVCanvasRect.z / 20.0) : squares.x;
	squares.y = (squares.y < 4.0) ? floor(fragData._VVCanvasRect.w / 20.0) : squares.y;
	
	float2 v = normalize(fadeSquareDirection);
	//if (v != float2(0.0))
	//v /= abs(v.x)+abs(v.y);
	if ((v.x != 0.)
	&& (v.y != 0.))	{
		v /= abs(v.x)+abs(v.y);
	}
	
	float		d = v.x * fadeSquareCenter.x + v.y * fadeSquareCenter.y;
	float		offset = fadeSquareSmoothness;
	float		pr = smoothstep(-offset, 0.0, v.x * p.x + v.y * p.y - (d-0.5+topAlpha*(1.+offset)));
	float2		squarep = fract(p*(squares));
	float2		squaremin = float2(pr/2.0);
	float2		squaremax = float2(1.0 - pr/2.0);
	//float		a = all(lessThan(squaremin, squarep)) && all(lessThan(squarep, squaremax)) ? 1.0 : 0.0;
	float		a = 0.0;
	if ((squaremin.x < squarep.x)
	&& (squaremin.y < squarep.y)
	&& (squarep.x < squaremax.x)
	&& (squarep.y < squaremax.y))	{
		a = 1.0;
	}
	
	returnMe = mix(darkenedBottom, top, a);
	return returnMe;
}


float4 CompositeBottom(thread float4 & bottom, thread float & topAlpha, thread MSLCompModeFragData & fragData)	{
	float2		p = fragData.gl_FragCoord.xy / fragData._VVCanvasRect.zw;
	float4		darkenedBottom = float4(fragData._VVCanvasRect.a) * fragData._VVCanvasRect;
	darkenedBottom.a = fragData._VVCanvasRect.a;
	float4		returnMe = darkenedBottom;
	float2 		squares = float2(floor(fragData._VVCanvasRect.z / 80.0),floor(fragData._VVCanvasRect.w / 80.0));
	squares.x = (squares.x < 4.0) ? floor(fragData._VVCanvasRect.z / 20.0) : squares.x;
	squares.y = (squares.y < 4.0) ? floor(fragData._VVCanvasRect.w / 20.0) : squares.y;
	
	float2 v = normalize(fadeSquareDirection);
	//if (v != float2(0.0))
	//v /= abs(v.x)+abs(v.y);
	if ((v.x != 0.)
	&& (v.y != 0.))	{
		v /= abs(v.x)+abs(v.y);
	}
	
	float		d = v.x * fadeSquareCenter.x + v.y * fadeSquareCenter.y;
	float		offset = fadeSquareSmoothness;
	float		pr = smoothstep(-offset, 0.0, v.x * p.x + v.y * p.y - (d-0.5+topAlpha*(1.+offset)));
	float2		squarep = fract(p*(squares));
	float2		squaremin = float2(pr/2.0);
	float2		squaremax = float2(1.0 - pr/2.0);
	//float		a = all(lessThan(squaremin, squarep)) && all(lessThan(squarep, squaremax)) ? 1.0 : 0.0;
	float		a = 0.0;
	if ((squaremin.x < squarep.x)
	&& (squaremin.y < squarep.y)
	&& (squarep.x < squaremax.x)
	&& (squarep.y < squaremax.y))	{
		a = 1.0;
	}
	
	returnMe = mix(darkenedBottom, bottom, a);
	return returnMe;
}
//vec4 CompositeTop(vec4 top, float topAlpha)	{
//	return vec4(0.0, 0.0, 0.0, 0.0);
//}
