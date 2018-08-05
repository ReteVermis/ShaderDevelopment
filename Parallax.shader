
Shader "ShaderDev/ParallaxMap"
{
	Properties
	{
		_Color ("MainColor", Color) = (1,1,1,1)
		_MainTex("Main Texture", 2D) = "white"{}
		_ParallaxOffset ("Parallax offset", Range (0,1)) = 0.1
		_AlphaSteps ("Alpha steps", Range (0,100)) = 1
	}
	Subshader{
		Tags { "Queue"="AlphaTest" "RenderType"="TransparentCutout" "IgnoreProjector"="True" }
		Pass{
			AlphaToMask On
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"
			uniform half4 _Color;
			uniform sampler2D _MainTex;
			uniform float _ParallaxOffset;
			uniform float _AlphaSteps;

			struct vertexInput
			{
				float4 position : POSITION;

				float4 normal : NORMAL;
				float4 tangent : TANGENT;

				float4 uv : TEXCOORD0;
			};

			struct vertexOutput
			{
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				float2 paralaxUV : TEXCOORD1;
			};



			vertexOutput vert(vertexInput v)
			{
				vertexOutput o; UNITY_INITIALIZE_OUTPUT(vertexOutput, o); // d3d11 requires initialization

				//Pass UV to output
				o.uv = v.uv;

				//Vertex position to Camera space for rendering geometry
				o.pos = UnityObjectToClipPos(v.position);

				//Verttex position into World Space position
				float4 worldPosition  = mul(unity_ObjectToWorld, v.position);

				//Obtaining World space TBN matrix
				float3 normalWorld = normalize(mul((float3x3)unity_ObjectToWorld, v.normal));
				float3 tangentWorld = normalize(mul((float3x3)unity_ObjectToWorld, v.tangent));
				float3 binormal = cross(v.normal, v.tangent.xyz);
				float3 binormalWorld = normalize(mul((float3x3)unity_ObjectToWorld, binormal));
				float3x3 TBN = float3x3(tangentWorld,binormalWorld,normalWorld);

				// Getting World Space view direction
				float3 viewdir = normalize(worldPosition.xyz - _WorldSpaceCameraPos.xyz);

				//-----------------   Parallax Magic   ----------------------
				//View direction to Tangent space
				viewdir = mul(TBN, viewdir);

				//P vector is UV offset which depends on camera view angle
				float2 P = viewdir.xy / viewdir.z;
				// Correcting Horizontal offset
				P.x *= -1; 
				// Multiplication by parameter to control parallax offset
				P = mul(P, _ParallaxOffset);

				// Clamping final values to avoid low angle distortions
				P = clamp(P,_ParallaxOffset*-1,_ParallaxOffset);

				//Adding parallax offset
				o.paralaxUV = v.uv + P;

				return o;
			}



			half4 frag(vertexOutput input) : COLOR
			{
				//Sampling texture without parallax offset
				float4 Color = tex2D(_MainTex, input.uv);

				//Here we have a cycle to offset alpha by parallax
				//_AlphaSteps parameter determines how many times alpha will be sampled
				for(float i=1; i<=_AlphaSteps; i++)
				{
					float4 sample = tex2D(_MainTex, lerp(input.uv,input.paralaxUV,i/_AlphaSteps));
					Color.w += sample.w;	
				}
				//Clamping alpha to avoid values over 1
				Color.w = clamp(Color.w,0,1);

				return Color;
			}
				
		
			ENDCG
		}
	}
}