Shader "ZZZ/ZZZ_body"
{
    Properties
    {
        [Header(Textures)]
        _BaseMap("Base Map" ,2D) = "white" {} //基础贴图采样

        [Header(AO)]
        [Toggle(_USE_AO_MAP)] _UseAOMap("Use AO Map" , Range(0,1)) = 1
        _AOMap("AO Map" ,2D) = "white" {} //AO贴图采样
        _AOIntensity("AO Intensity", Range(0,1)) = 1.0 //AO强度

        [Header(Specular)]
        _SpecularMap("Specular Map" ,2D) = "black"{} //高光贴图采样
        _SpecularPower("Specular Power", Range(0,1)) = 0.25 //高光强度
        _SpecularRegion("Specular Region", Range(0,1)) = 0.3 //高光范围

        [Header(Ramp)]
        [Toggle(_USE_RAMPMAP)] _UseRampMap("Use RampMap" , Range(0,1)) = 1
        _RampMap("Ramp Map" ,2D) = "black"{}
        _RampOffset("Ramp Offset" ,Range(-1,1)) = 0 //阴影区域偏移
        _RampWidth("Ramp Width" , Range(0,1)) = 0.55 //阴影边界宽度
        _RampSoftness("Ramp Softness" ,Range(0.001,1)) = 0.1 //阴影边界柔和度

        [Header(Colour Modulation)]
        _ColourModulation("Colour Modulation" ,Color) = (1,1,1,1)//调色
        _Saturation("Saturation", Range(0,2)) = 1.0//饱和度调节
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"
        }

        HLSLINCLUDE//公共代码块

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl" // 核心库
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl" // 光照库

            #pragma shader_feature_local _USE_RAMPMAP
            #pragma shader_feature_local _USE_AO_MAP

            // 纹理声明
            TEXTURE2D(_BaseMap);        SAMPLER(sampler_BaseMap);
            TEXTURE2D(_AOMap);          SAMPLER(sampler_AOMap);
            TEXTURE2D(_SpecularMap);    SAMPLER(sampler_SpecularMap);
            TEXTURE2D(_RampMap);        SAMPLER(sampler_RampMap);

            // 材质属性常量缓冲区
            CBUFFER_START(UnityPerMaterial)
                // 基础纹理
                float4 _BaseMap_ST;
                
                // AO
                float4 _AOMap_ST;
                half _AOIntensity;

                // 高光项
                float4 _SpecularMap_ST;
                half _SpecularPower;
                half _SpecularRegion;
                
                // Ramp色阶阴影
                half _RampOffset;
                half _RampWidth;
                half _RampSoftness;
                
                // 调色
                float4 _ColourModulation;
                half _Saturation;
            CBUFFER_END

        ENDHLSL

        pass
        {
            Name "UniversalForward"//给pass通道命名

            Tags
            {
                "LightMode" = "UniversalForward"
            }

            Cull off //背面剔除

            HLSLPROGRAM

                #pragma vertex vert
                #pragma fragment frag

                struct Attributes
                {
                    float4 positionOS : POSITION;   // 模型空间坐标
                    float2 uv0        : TEXCOORD0;  // UV
                    float2 uv1        : TEXCOORD1;  // 高光
                    float3 normalOS   : NORMAL;     // 模型空间法线
                };

                struct Varyings
                {
                    float4 positionCS : SV_POSITION; // 裁剪空间坐标
                    float2 uv0        : TEXCOORD0;   // 主纹理 UV
                    float2 uv1        : TEXCOORD1;   // 高光贴图 UV
                    float3 normalWS   : TEXCOORD2;   // 世界空间法线
                };

                Varyings vert(Attributes i)
                {
                    Varyings o;

                    // 模型空间 → 裁剪空间
                    o.positionCS = TransformObjectToHClip(i.positionOS.xyz);

                    // UV 传递（应用 Tiling/Offset）
                    o.uv0 = TRANSFORM_TEX(i.uv0, _BaseMap);
                    o.uv1 = TRANSFORM_TEX(i.uv1, _SpecularMap);

                    // normal
                    VertexNormalInputs normalInput = GetVertexNormalInputs(i.normalOS);//转换法线空间
                    o.normalWS = normalInput.normalWS;//将世界坐标法线传递给输出变量
                    
                    return o;
                }

                half4 frag(Varyings i) : SV_TARGET
                {
                    // 采样光源
                    Light light = GetMainLight();

                    // Lambert Diffuse
                    half4 basecolor    = SAMPLE_TEXTURE2D(_BaseMap,    sampler_BaseMap,    i.uv0);
                    half4 specularMap  = SAMPLE_TEXTURE2D(_SpecularMap, sampler_SpecularMap, i.uv1);
                    half3 N = normalize(i.normalWS);
                    half3 L = normalize(light.direction);
                    half NdotL = saturate(dot(N, L));
                    half halfLambert = saturate(NdotL * 0.5 + 0.5); //半lambert 
                    halfLambert = halfLambert * halfLambert * halfLambert; //增加效果
                    halfLambert = lerp(halfLambert,0,step(halfLambert,0.05));
                    halfLambert = lerp(halfLambert,1,step(0.95,halfLambert));

                    // AO 强度调节：1 = 无AO效果，ao值越小遮蔽越强
                    half ao = SAMPLE_TEXTURE2D(_AOMap,sampler_AOMap,i.uv0);
                    ao = lerp(1.0, ao, _AOIntensity);
                    ao = (ao+halfLambert)*0.5;

                    // Ramp色阶阴影
                    half center = _RampOffset + 0.5;
                    half shadowMask = smoothstep((center + _RampWidth) , (center - _RampWidth) , NdotL); 
                    shadowMask = smoothstep((0.5+_RampSoftness),(0.5-_RampSoftness),shadowMask);
                    half2 rampUV = half2(shadowMask,0.5);
                    half3 rampColor = SAMPLE_TEXTURE2D(_RampMap,sampler_RampMap,rampUV).rgb;

                    // 最终颜色
                    half3 duffuse = basecolor.rgb * light.color * halfLambert;
                    half3 color = duffuse;

                    // 高光（大于0.3使用）
                    if(halfLambert>1-_SpecularRegion)
                    {
                        color.rgb += specularMap.rgb * _SpecularPower * halfLambert;
                    }

                    #if _USE_RAMPMAP
                        color *= rampColor;
                    #endif

                    #if _USE_AO_MAP
                        color *= (ao+0.2);
                    #endif

                    return half4(color,basecolor.a);
                }

            ENDHLSL
        }
    }
}
