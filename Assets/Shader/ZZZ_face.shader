Shader "ZZZ/ZZZ_face"
{
    Properties
    {
        [Header(Textures)]
        _BaseMap("Base Map" ,2D) = "white" {}
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
        }

        HLSLINCLUDE//公共代码块

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl" // 核心库
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl" // 光照库

        ENDHLSL

        pass
        {
            Name "UniversalForward"//给pass通道命名

            Tags
            {
                "LightMode" = "UniversalForward"
            }

            HLSLPROGRAM

                #pragma vertex vert
                #pragma fragment frag

                // 纹理声明
                TEXTURE2D(_BaseMap);
                SAMPLER(sampler_BaseMap);

                // 材质属性常量缓冲区
                CBUFFER_START(UnityPerMaterial)
                    float4 _BaseMap_ST;
                CBUFFER_END

                struct Attributes
                {
                    float4 positionOS : POSITION;   // 模型空间坐标
                    float2 uv0        : TEXCOORD0;  // UV
                    float3 normalOS   : NORMAL;     // 模型空间法线
                };

                struct Varyings
                {
                    float4 positionCS : SV_POSITION; // 裁剪空间坐标
                    float2 uv0        : TEXCOORD0;   // 主纹理 UV
                    float3 normalWS   : TEXCOORD2;   // 世界空间法线
                };

                Varyings vert(Attributes i)
                {
                    Varyings o;

                    // 模型空间 → 裁剪空间
                    o.positionCS = TransformObjectToHClip(i.positionOS.xyz);

                    // UV 传递（应用 Tiling/Offset）
                    o.uv0 = TRANSFORM_TEX(i.uv0, _BaseMap);
                    // 法线：模型空间 → 世界空间
                    o.normalWS = TransformObjectToWorldNormal(i.normalOS);

                    return o;
                }

                half4 frag(Varyings i) : SV_TARGET
                {
                    // 采样光源
                    Light light = GetMainLight();

                    // 采样纹理
                    half4 basecolor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, i.uv0);

                    // 归一化向量
                    half3 N = normalize(i.normalWS);
                    half3 L = normalize(light.direction);

                    // ===== 漫反射（Half-Lambert）=====
                    half NdotL = saturate(dot(N, L));
                    half halfLambert = saturate(NdotL * 0.5 + 0.5);
                    halfLambert = halfLambert * halfLambert * halfLambert;

                    // ===== 最终颜色 = 漫反射 + 高光贴图 =====
                    half4 color = half4(basecolor.rgb * light.color * halfLambert, basecolor.a);

                    return color;
                }

            ENDHLSL
        }
    }
}