Shader "ZZZ/ZZZ_face"
{
    Properties
    {
        [Header(Textures)]
        _BaseMap("Base Map" ,2D) = "white" {}

        [Header(Outline)]
        _OutlineWidth("Outline Width", Range(0, 10)) = 2.0 //描边宽度（像素级）
        _OutlineColor("Outline Color", Color) = (0, 0, 0, 1) //描边颜色
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

            // 材质属性常量缓冲区（所有 Pass 共用，保证 SRP Batcher 兼容）
            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                half _OutlineWidth;
                half4 _OutlineColor;
            CBUFFER_END

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

                    return (1,1,1,1);
                }

            ENDHLSL
        }

        pass
        {
            Name "Outline"

            Tags
            {
                "LightMode" = "SRPDefaultUnlit" // URP 默认会绘制，保证主相机下描边可见
            }

            Cull Front  // 剔除正面，只渲染膨胀后的背面，形成轮廓
            ZWrite On
            ZTest LEqual

            HLSLPROGRAM

                #pragma vertex vertOutline
                #pragma fragment fragOutline

                struct OutlineAttributes
                {
                    float4 positionOS : POSITION;   // 模型空间坐标
                    float3 normalOS   : NORMAL;     // 模型空间法线
                };

                struct OutlineVaryings
                {
                    float4 positionCS : SV_POSITION;
                };

                OutlineVaryings vertOutline(OutlineAttributes v)
                {
                    OutlineVaryings o;

                    VertexPositionInputs posInputs = GetVertexPositionInputs(v.positionOS.xyz);
                    o.positionCS = posInputs.positionCS;

                    // 1. 观察空间法线（用于决定膨胀方向）
                    //    用 GetVertexNormalInputs + TransformWorldToViewDir，与 forward Pass 一致，
                    //    内部走逆转置(UNITY_MATRIX_I_M)，非均匀缩放下法线方向也正确
                    VertexNormalInputs normalInput = GetVertexNormalInputs(v.normalOS); // 转换法线空间
                    float3 normalVS = TransformWorldToViewDir(normalInput.normalWS, true);

                    // 2. 裁剪空间下沿法线方向膨胀：
                    //    - normalize 后乘 _OutlineWidth 得到像素级偏移量
                    //    - 除以 _ScreenParams.xy*0.5 把像素偏移转为 NDC 偏移，修正屏幕宽高比
                    //    - 乘 positionCS.w 从 NDC 还原到裁剪空间，保证透视下描边粗细一致
                    float2 extent = normalize(normalVS.xy) * _OutlineWidth;
                    extent /= _ScreenParams.xy * 0.5;
                    o.positionCS.xy += extent * o.positionCS.w;

                    return o;
                }

                half4 fragOutline(OutlineVaryings i) : SV_TARGET
                {
                    return half4(_OutlineColor.rgb, 1.0);
                }

            ENDHLSL
        }
    }
}