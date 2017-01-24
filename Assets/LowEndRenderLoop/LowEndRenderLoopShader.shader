// Shader targeted for LowEnd mobile devices. Single Pass Forward Rendering. Shader Model 2
//
// The parameters and inspector of the shader are the same as Standard shader,
// for easier experimentation.
Shader "RenderLoop/LowEnd"
{
	// Properties is just a copy of Standard (Specular Setup).shader. Our example shader does not use all of them,
	// but the inspector UI expects all these to exist.
	Properties
	{
		_Color("Color", Color) = (1,1,1,1)
		_MainTex("Albedo", 2D) = "white" {}

		_Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5

		_Glossiness("Smoothness", Range(0.0, 1.0)) = 0.5
		_GlossMapScale("Smoothness Factor", Range(0.0, 1.0)) = 1.0
		[Enum(Specular Alpha,0,Albedo Alpha,1)] _SmoothnessTextureChannel("Smoothness texture channel", Float) = 0

		_SpecColor("Specular", Color) = (0.2,0.2,0.2)
		_SpecGlossMap("Specular", 2D) = "white" {}
		[ToggleOff] _SpecularHighlights("Specular Highlights", Float) = 1.0
		[ToggleOff] _GlossyReflections("Glossy Reflections", Float) = 1.0

		_BumpScale("Scale", Float) = 1.0
		_BumpMap("Normal Map", 2D) = "bump" {}

		_Parallax("Height Scale", Range(0.005, 0.08)) = 0.02
		_ParallaxMap("Height Map", 2D) = "black" {}

		_OcclusionStrength("Strength", Range(0.0, 1.0)) = 1.0
		_OcclusionMap("Occlusion", 2D) = "white" {}

		_EmissionColor("Color", Color) = (0,0,0)
		_EmissionMap("Emission", 2D) = "white" {}

		_DetailMask("Detail Mask", 2D) = "white" {}

		_DetailAlbedoMap("Detail Albedo x2", 2D) = "grey" {}
		_DetailNormalMapScale("Scale", Float) = 1.0
		_DetailNormalMap("Normal Map", 2D) = "bump" {}

		[Enum(UV0,0,UV1,1)] _UVSec("UV Set for secondary textures", Float) = 0

		// Blending state
		[HideInInspector] _Mode("__mode", Float) = 0.0
		[HideInInspector] _SrcBlend("__src", Float) = 1.0
		[HideInInspector] _DstBlend("__dst", Float) = 0.0
		[HideInInspector] _ZWrite("__zw", Float) = 1.0
	}

	SubShader
	{
		Tags { "RenderType" = "Opaque" "PerformanceChecks" = "False" }
		LOD 300

		// Include forward (base + additive) pass from regular Standard shader.
		// They are not used by the scriptable render loop; only here so that
		// if we turn off our example loop, then regular forward rendering kicks in
		// and objects look just like with a Standard shader.
		UsePass "Standard (Specular setup)/FORWARD"
		UsePass "Standard (Specular setup)/FORWARD_DELTA"

		Pass
		{
			Name "SINGLE_PASS_FORWARD"
			Tags { "LightMode" = "LowEndForwardBase" }

			// Use same blending / depth states as Standard shader
			Blend[_SrcBlend][_DstBlend]
			ZWrite[_ZWrite]

			CGPROGRAM
			#pragma target 2.0
			#pragma vertex vert
			#pragma fragment frag
			#pragma shader_feature _SPECGLOSSMAP
			#pragma shader_feature _NORMALMAP
			
			#pragma multi_compile _ LIGHTMAP_ON
			#pragma multi_compile_fog
			#pragma only_renderers d3d9 d3d11 d3d11_9x glcore gles gles3
			//#pragma enable_d3d11_debug_symbols
			
			#include "UnityCG.cginc"
			#include "UnityStandardBRDF.cginc"
			#include "UnityStandardInput.cginc"
			#include "UnityStandardUtils.cginc"

			#define DEBUG_CASCADES 0
			#define MAX_SHADOW_CASCADES 4
			#define MAX_LIGHTS 8

			#define INITIALIZE_LIGHT(light, lightIndex) \
				light.pos = globalLightPos[lightIndex]; \
				light.color = globalLightColor[lightIndex]; \
				light.atten = globalLightAtten[lightIndex]; \
				light.spotDir = globalLightSpotDir[lightIndex]

			#define FRESNEL_TERM(normal, viewDir) Pow4(1.0 - saturate(dot(normal, viewDir)))

			// TODO: Add metallic or specular reflectivity
			#define GRAZING_TERM _Glossiness 

			// The variables are very similar to built-in unity_LightColor, unity_LightPosition,
			// unity_LightAtten, unity_SpotDirection as used by the VertexLit shaders, except here
			// we use world space positions instead of view space.
			half4 globalLightColor[MAX_LIGHTS];
			float4 globalLightPos[MAX_LIGHTS];
			half4 globalLightSpotDir[MAX_LIGHTS];
			half4 globalLightAtten[MAX_LIGHTS];
			int4  globalLightCount; // x: pixelLightCount, y = totalLightCount (pixel + vert)

			sampler2D g_tShadowBuffer;

			half4x4 _WorldToShadow[MAX_SHADOW_CASCADES];
			half4 _PSSMDistances;

			struct LightInput
			{
				half4 pos;
				half4 color;
				half4 atten;
				half4 spotDir;
			};

			inline int ComputeCascadeIndex(half eyeZ)
			{
				// PSSMDistance is set to infinity for non active cascades. This way the comparison for unavailable cascades will always be zero. 
				half3 cascadeCompare = step(_PSSMDistances, half3(eyeZ, eyeZ, eyeZ));
				return dot(cascadeCompare, cascadeCompare);
			}

			inline half3 EvaluateOneLight(LightInput lightInput, half3 diffuseColor, half3 specularColor, half3 normal, float3 posWorld, half3 viewDir)
			{
				float3 posToLight = lightInput.pos.xyz;
				posToLight -= posWorld * lightInput.pos.w;

				float distanceSqr = max(dot(posToLight, posToLight), 0.001);
				float lightAtten = 1.0 / (1.0 + distanceSqr * lightInput.atten.z);

				float3 lightDir = posToLight * rsqrt(distanceSqr);
				float SdotL = saturate(dot(lightInput.spotDir.xyz, lightDir));
				lightAtten *= saturate((SdotL - lightInput.atten.x) / lightInput.atten.y);

				float cutoff = step(distanceSqr, lightInput.atten.w); 
				lightAtten *= cutoff;

				float NdotL = saturate(dot(normal, lightDir));
				
				half3 halfVec = normalize(lightDir + viewDir);
				half NdotH = saturate(dot(normal, halfVec));

				half3 lightColor = lightInput.color.rgb * lightAtten;
				half3 diffuse = diffuseColor * lightColor * NdotL;
				half3 specular = specularColor * lightColor * pow(NdotH, 128.0f) * _Glossiness;
				return diffuse + specular;
			}

			inline half3 EvaluateMainLight(LightInput lightInput, half3 diffuseColor, half3 specularColor, half3 normal, float4 posWorld, half3 viewDir)
			{
				int cascadeIndex = ComputeCascadeIndex(posWorld.w);
				float3 shadowCoord = mul(_WorldToShadow[cascadeIndex], float4(posWorld.xyz, 1.0));
				shadowCoord.z = saturate(shadowCoord.z);

				half shadowDepth = tex2D(g_tShadowBuffer, shadowCoord.xy).r;
				half shadowAttenuation = 1.0;
				
#if defined(UNITY_REVERSED_Z)
				shadowAttenuation = step(shadowDepth, shadowCoord.z);
#else
				shadowAttenuation = step(shadowCoord.z, shadowDepth);
#endif

#if DEBUG_CASCADES
				half3 cascadeColors[MAX_SHADOW_CASCADES] = { half3(1.0, 0.0, 0.0), half3(0.0, 1.0, 0.0),  half3(0.0, 0.0, 1.0),  half3(1.0, 0.0, 1.0) };
				return cascadeColors[cascadeIndex] * diffuseColor * max(shadowAttenuation, 0.5); 
#endif

				half3 color = EvaluateOneLight(lightInput, diffuseColor, specularColor, normal, posWorld, viewDir);
				return color * shadowAttenuation;
			}

			struct LowendVertexInput
			{
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 tangent : TANGENT;
				float3 texcoord : TEXCOORD0;
				float2 lightmapUV : TEXCOORD1;
			};

			struct v2f
			{
				float4 uv01 : TEXCOORD0; // uv01.xy: uv0, uv01.zw: uv1
				float4 posWS : TEXCOORD1; // xyz: posWorld, w: eyeZ
#if _NORMALMAP
				half3 tangentToWorld[3] : TEXCOORD2; // tangentToWorld matrix
#else
				half3 normal : TEXCOORD2;
#endif
				half4 viewDir : TEXCOORD5; // xyz: viewDir, w: grazingTerm;
				UNITY_FOG_COORDS_PACKED(6, half4) // x: fogCoord, yzw: vertexColor
				float4 hpos : SV_POSITION;
			}; 

			v2f vert(LowendVertexInput v)
			{ 
				v2f o;
				UNITY_INITIALIZE_OUTPUT(v2f, o);

				o.uv01.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.uv01.zw = v.lightmapUV * unity_LightmapST.xy + unity_LightmapST.zw;
				o.hpos = UnityObjectToClipPos(v.vertex);

				o.posWS.xyz = mul(unity_ObjectToWorld, v.vertex).xyz;
				o.posWS.w = -UnityObjectToViewPos(v.vertex).z;

				o.viewDir.xyz = normalize(_WorldSpaceCameraPos - o.posWS.xyz);
#if !GLOSSMAP
				o.viewDir.w = GRAZING_TERM;
#endif
				half3 normal = normalize(UnityObjectToWorldNormal(v.normal));
				half fresnelTerm = FRESNEL_TERM(normal, o.viewDir.xyz);

#if _NORMALMAP
				half sign = v.tangent.w * unity_WorldTransformParams.w;
				half3 tangent = normalize(UnityObjectToWorldDir(v.tangent));
				half3 binormal = cross(normal, tangent) * v.tangent.w;

				// Initialize tangetToWorld in column-major to benefit from better glsl matrix multiplication code
				o.tangentToWorld[0] = half3(tangent.x, binormal.x, normal.x);
				o.tangentToWorld[1] = half3(tangent.y, binormal.y, normal.y);
				o.tangentToWorld[2] = half3(tangent.z, binormal.z, normal.z);
#else
				o.normal = normal;
#endif

				half3 diffuseAndSpecularColor = half3(1.0, 1.0, 1.0);
				for (int lightIndex = globalLightCount.x; lightIndex < globalLightCount.y; ++lightIndex)
				{
					LightInput lightInput;
					INITIALIZE_LIGHT(lightInput, lightIndex);
					o.fogCoord.yzw += EvaluateOneLight(lightInput, diffuseAndSpecularColor, diffuseAndSpecularColor, normal, o.posWS.xyz, o.viewDir.xyz);
				}

#ifndef LIGHTMAP_ON
				o.fogCoord.yzw += max(half3(0, 0, 0), ShadeSH9(half4(normal, 1)));
#endif

				o.fogCoord.x = 1.0;
				UNITY_TRANSFER_FOG(o, o.hpos);
				return o;
			}

			half4 frag(v2f i) : SV_Target
			{
#if _NORMALMAP
				half3 normalmap = UnpackNormal(tex2D(_BumpMap, i.uv01.xy));
				
				// glsl compiler will generate underperforming code by using a row-major pre multiplication matrix: mul(normalmap, i.tangentToWorld)
				// i.tangetToWorld was initialized as column-major in vs and here dot'ing individual for better performance. 
				// The code below is similar to post multiply: mul(i.tangentToWorld, normalmap)
				half3 normal = half3(dot(normalmap, i.tangentToWorld[0]), dot(normalmap, i.tangentToWorld[1]), dot(normalmap, i.tangentToWorld[2]));
#else
				half3 normal = normalize(i.normal);
#endif
				float3 posWorld = i.posWS.xyz;
				half3 viewDir = i.viewDir.xyz;

				half4 diffuseAlbedo = tex2D(_MainTex, i.uv01.xy);
				half3 diffuse = diffuseAlbedo.rgb *_Color.rgb;
				half alpha = diffuseAlbedo.a * _Color.a;

				half4 specGloss = SpecularGloss(i.uv01.xy);
				half3 specular = specGloss.rgb;
				half smoothness = specGloss.a;

				half oneMinusReflectivity;
				
				// Note: UnityStandardCoreForwardSimple is not energy conserving. The lightmodel from LDPipeline will appear
				// slither darker when comparing to Standard Simple due to this.
				diffuse = EnergyConservationBetweenDiffuseAndSpecular(diffuse, specular, /*out*/ oneMinusReflectivity);
				
				// Indirect Light Contribution
				half3 indirectDiffuse;
#ifdef LIGHTMAP_ON
				indirectDiffuse = DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, i.uv01.zw)) * diffuse;
#else
				indirectDiffuse = i.fogCoord.yzw * diffuse;
#endif
				// Compute direct contribution from main directional light.
				// Only a single directional shadow caster is supported.
				LightInput mainLight;
				INITIALIZE_LIGHT(mainLight, 0);

#if DEBUG_CASCADES
				return half4(EvaluateMainLight(mainLight, diffuse, specular, normal, i.posWS, viewDir), 1.0);
#endif
				half3 directColor = EvaluateMainLight(mainLight, diffuse, specular, normal, i.posWS, viewDir);

				// Compute direct contribution from additional lights.
				for (int lightIndex = 1; lightIndex < globalLightCount.x; ++lightIndex)
				{
					LightInput additionalLight;
					INITIALIZE_LIGHT(additionalLight, lightIndex);
					directColor += EvaluateOneLight(additionalLight, diffuse, specular, normal, posWorld, viewDir);
				}

				half3 color = directColor + indirectDiffuse + _EmissionColor;
				UNITY_APPLY_FOG(i.fogCoord, color);
				return half4(color, diffuseAlbedo.a);
			};
			ENDCG
		}

		Pass
		{
			Name "SHADOW_CASTER"
			Tags { "Lightmode" = "ShadowCaster" }

			ZWrite On ZTest LEqual Cull Front

			CGPROGRAM
			#pragma target 2.0
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"
			float4 vert(float4 position : POSITION) : SV_POSITION
			{
				float4 clipPos = UnityObjectToClipPos(position);
				return UnityApplyLinearShadowBias(clipPos);
			}

			half4 frag() : SV_TARGET
			{
				return 0;
			}
			ENDCG
		}
	}
	Fallback "RenderLoop/Error"
	CustomEditor "StandardShaderGUI"
}