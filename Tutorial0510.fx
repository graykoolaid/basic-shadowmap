//--------------------------------------------------------------------------------------
// File: Tutorial0510.fx
//
// Copyright (c) Microsoft Corporation. All rights reserved.
//--------------------------------------------------------------------------------------

//DEBUG
//fxc /Od /Zi /T fx_4_0 /Fo BasicHLSL10.fxo BasicHLSL10.fx

Texture2D txDiffuse0;
Texture2D txDiffuse1;
Texture2D shadowMap;


Texture2D shaderTextures[20];
int texSelect;

//--------------------------------------------------------------------------------------
// Constant Buffer Variables
//--------------------------------------------------------------------------------------
cbuffer cbNeverChanges
{
	matrix View;
};
    
cbuffer cbChangeOnResize
{
    matrix Projection;
};
    
cbuffer cbChangesEveryFrame
{
    matrix World;
	float4 vLightDir[10];
	float4 vLightColor[10];
	float4 vOutputColor;
	int		texSelectIndex;

	float4x4 lightViewProj;
	float4x4 lightView;
};




SamplerState samLinear
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Wrap;
    AddressV = Wrap;
};

SamplerState pointSampler
{
	Filter = MIN_MAG_MIP_POINT;
	AddressU = MIRROR;
	AddressV = MIRROR;
};


//--------------------------------------------------------------------------------------
struct VS_INPUT
{
    float4 Pos		: POSITION;
	float4 Normal	: NORMAL;
	float2 Tex		: TEXCOORD;
	int TexNum	    : TEXNUM;
};

struct PS_INPUT
{
    float4 Pos		: SV_POSITION;
	float4 Normal	: NORMAL;
	float2 Tex		: TEXCOORD0;
	int TexNum      : TEXNUM;
	float4 lpos		: TEXCOORD1;
	float4 wpos		: TEXCOORD2;
};


PS_INPUT VS( VS_INPUT input )
{
	PS_INPUT output = (PS_INPUT)0;
	   
    output.Pos = mul( input.Pos, World );
    output.Pos = mul( output.Pos, View );
    output.Pos = mul( output.Pos, Projection );
    output.Normal = mul( input.Normal, World );
    output.Tex    = input.Tex;
	output.TexNum = input.TexNum;

	output.lpos = mul( mul(input.Pos, World), mul(lightView,Projection)  );
	//output.lpos = mul( mul(input.Pos, World), lightViewProj  );
	//output.lpos = mul( output.Pos, mul(View,lightViewProj)  );
	//output.lpos = mul( output.Pos, lightViewProj );
	//output.lpos = mul( mul(input.Pos, World), lightViewProj  );
	//output.wpos = input.Pos;
	output.wpos = mul( input.Pos, World );


    return output;
}

float ambient = .3;
float diffuse = .6;
float SHADOW_VAL( PS_INPUT input)
{
 //re-homogenize position after interpolation
    input.lpos.xyz /= input.lpos.w;
 
	    if( input.lpos.x < -1.0f || input.lpos.x > 1.0f ||
        input.lpos.y < -1.0f || input.lpos.y > 1.0f ||
        input.lpos.z < 0.0f  || input.lpos.z > 1.0f ) return ambient;

    //transform clip space coords to texture space coords (-1:1 to 0:1)
    input.lpos.x = input.lpos.x/2 + 0.5;
    input.lpos.y = input.lpos.y/-2 + 0.5;
 
    //sample shadow map - point sampler
	float shadowMapDepth = shadowMap.Sample(pointSampler, input.lpos.xy).r;
	//return float4( shadowMapDepth, shadowMapDepth, shadowMapDepth, 1.0 );

    //if clip space z value greater than shadow map value then pixel is in shadow
    if ( shadowMapDepth < input.lpos.z) return ambient;
 
    //otherwise calculate ilumination at fragment
    float3 L = normalize((float3)vLightDir[0] - input.wpos.xyz);
    float ndotl = dot( normalize(input.Normal), L);
    return ambient + diffuse*ndotl;
}


float4 PS( PS_INPUT input) : SV_Target
{
	float4 LightColor = 0;

	float4 textureFinal = float4( 1.0,1.0,1.0,1.0 );
        
    //do NdotL lighting for 2 lights
    for(int i=0; i<4; i++)
    {
        LightColor += saturate( dot( (float3)vLightDir[i],input.Normal) * vLightColor[i]);
    }

	LightColor.a = 1.0;

	if( texSelect == input.TexNum)
		return float4( 0.0, 1.0, 0.0, 0.0 );


	if( texSelect == -2 )
		textureFinal = float4( 0.0, (1.0 -( (float)input.TexNum * .10)), 0.0, 1.0 );

		int texnum = input.TexNum;
		
	//quick hack to make to expand it to large values. change 10 if more than 10 tex on an object
	for( int i = 0; i < 10; i++ )
	{
		if( i == input.TexNum )
		{
			textureFinal = shaderTextures[i].Sample( samLinear, input.Tex )*LightColor;
		}
	}

	clip( textureFinal.a - .9f );


	float shadow = SHADOW_VAL( input );


	//if this is white you got issues
	return textureFinal * shadow;
	//return float4( 1.0, 1.0, 1.0, 1.0 );

}

//------------------------------------------------------
// Render ShadowMap
//-----------------------------------------------------
PS_INPUT ShadowMapVS( VS_INPUT input )
{
	PS_INPUT output = (PS_INPUT)0;
	   
	output.Pos = mul( input.Pos, World  );
	output.Pos = mul( output.Pos, lightView );
	output.Pos = mul( output.Pos, lightViewProj );
    output.Normal = mul( input.Normal, World );
    output.Tex    = input.Tex;
	output.TexNum = input.TexNum;
	//return input.Pos.z;
    return output;
}

float ShadowMapPS( PS_INPUT input ) : SV_Depth
{
	float depth = input.Pos.z / input.Pos.w;
	return depth;
}


//--------------------------------------------------------------------------------------
technique10 Render
{
    pass P0
    {
        SetVertexShader( CompileShader( vs_4_0, VS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_4_0, PS() ) );
    }
}

//--------------------------------------------------------------------------------------
technique10 RenderShadowMap
{
    pass P0
    {
        SetVertexShader( CompileShader( vs_4_0, ShadowMapVS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( NULL );
    }
}
