Shader "ZZZ/ZZZ_mekage"
{
    Properties
    {
        _BaseMap("Base Map", 2D) = "white" {}
        [HDR] _MixColor("Mix Color", Color) = (1, 1, 1, 1)
        _Brightness("Brightness", Range(0, 3)) = 1.0
        _MekageAlpha("Mekage Alpha", Range(0, 2)) = 0.5

        [Header(Lighting)]
        _LightInfluence("Light Influence", Range(0, 1)) = 0.5
        _AmbientStrength("Ambient Strength", Range(0, 1)) = 0.15
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Transparent"
            "Queue" = "Geometry+10"
        }

        Pass
        {
            Name "UniversalForward"

            Tags
            {
                "LightMode" = "UniversalForward"
            }

            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            ZTest LEqual
            Cull Back

            HLSLPROGRAM
                #pragma vertex vert
                #pragma fragment frag

                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

                TEXTURE2D(_BaseMap);
                SAMPLER(sampler_BaseMap);

                CBUFFER_START(UnityPerMaterial)
                    float4 _BaseMap_ST;
                    half4 _MixColor;
                    half _Brightness;
                    half _MekageAlpha;
                    half _LightInfluence;
                    half _AmbientStrength;
                CBUFFER_END

                struct Attributes
                {
                    float4 positionOS : POSITION;
                    float3 normalOS   : NORMAL;
                    float2 uv         : TEXCOORD0;
                };

                struct Varyings
                {
                    float4 positionHCS : SV_POSITION;
                    float3 normalWS    : TEXCOORD0;
                    float2 uv          : TEXCOORD1;
                };

                Varyings vert(Attributes input)
                {
                    Varyings output;
                    output.positionHCS = TransformObjectToHClip(input.positionOS.xyz);
                    output.normalWS    = TransformObjectToWorldNormal(input.normalOS);
                    output.uv          = TRANSFORM_TEX(input.uv, _BaseMap);
                    return output;
                }

                half4 frag(Varyings input) : SV_TARGET
                {
                    half4 basecolor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);

                    // 柔和吃主光色与环境光（不用薄片自身 N·L 切硬边，避免眼影/高光出现奇怪折痕）
                    Light mainLight = GetMainLight();
                    half3 N = SafeNormalize(input.normalWS);
                    half3 envLight = mainLight.color * mainLight.distanceAttenuation
                                   + max(0.0, SampleSH(N)) * _AmbientStrength;
                    half3 lightFactor = lerp(half3(1.0, 1.0, 1.0), envLight, _LightInfluence);

                    half4 outColor;
                    outColor.rgb = basecolor.rgb * _MixColor.rgb * _Brightness * lightFactor;
                    outColor.a   = saturate(basecolor.a * _MixColor.a * _MekageAlpha);
                    return outColor;
                }
            ENDHLSL
        }
    }
}
