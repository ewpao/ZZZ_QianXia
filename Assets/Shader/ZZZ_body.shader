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
        _RampID("RampID" , 2D) = "white"{}
        _ShadowThreshold("Shadow Threshold",Range(0,1)) = 0.3 //阴影阈值（边缘位置）
        _ShadowSoftness("Shadow Softness" ,Range(0.001,1)) = 0.001 //阴影边界柔和度（调节阴影软硬）
        _ShadowIntensity("Shadow Intensity" , Range(0,1)) = 1 //阴影强度

        [Header(Rim)]
        [Toggle(_USE_RIM_LIGHT)] _UseRimLight("Use Rim Light" , Range(0,1)) = 1 //Rim边缘光开关
        _OffsetMul("Rim Width" ,Range(0.01,0.1)) = 0.01 // 偏移量乘积代表边缘光宽度
        _RimThreshold("Rim Threshold" ,Range(0,1)) = 0.9 // 差值的阈值


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
            TEXTURE2D(_RampID);         SAMPLER(sampler_RampID);

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
                half _ShadowThreshold;
                half _ShadowSoftness;
                half _ShadowIntensity;

                // Rim边缘光
                half _UseRimLight;
                half _OffsetMul;
                half _RimThreshold;

                // 调色
                float4 _ColourModulation;
                half _Saturation;
            CBUFFER_END

            half GetrampV(half3 rampIDtu)
            {
                half v = 0.1;
                if (rampIDtu.r>0.6){
                    v=0.9;
                }
                if (rampIDtu.g>0.6){
                    v=0.5;
                }
                if (rampIDtu.b>0.6){
                    v=0.3;
                }
                return v;
            }

            struct Attributes
            {
                float4 positionOS : POSITION;   // 模型空间坐标
                float2 uv0        : TEXCOORD0;  // UV
                float2 uv1        : TEXCOORD1;  // 高光
                float3 normalOS   : NORMAL;     // 模型空间法线
                float4 color      : COLOR0;     // 顶点颜色
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION; // 裁剪空间坐标
                float2 uv0        : TEXCOORD0;   // 主纹理 UV
                float2 uv1        : TEXCOORD1;   // 高光贴图 UV
                float3 normalWS   : TEXCOORD2;   // 世界空间法线
                float4 color      : COLOR0;      // 顶点颜色
            };

        ENDHLSL

        pass
        {
            Name "UniversalForward"//给pass通道命名

            Tags
            {
                "LightMode" = "UniversalForward"
            }

            Cull back //背面剔除关闭

            HLSLPROGRAM

                #pragma vertex vert
                #pragma fragment frag

                Varyings vert(Attributes i)
                {
                    Varyings o;

                    // 空间转换
                    o.positionCS = TransformObjectToHClip(i.positionOS.xyz);//模型空间->裁剪空间


                    // UV 传递（应用 Tiling/Offset）
                    o.uv0 = TRANSFORM_TEX(i.uv0, _BaseMap);
                    o.uv1 = TRANSFORM_TEX(i.uv1, _SpecularMap);

                    // normal
                    VertexNormalInputs normalInput = GetVertexNormalInputs(i.normalOS);//转换法线空间
                    o.normalWS = normalInput.normalWS;//将世界坐标法线传递给输出变量

                    //color
                    o.color = i.color;
                    
                    return o;
                }

                half4 frag(Varyings i) : SV_TARGET
                {
                    // 采样光源
                    Light light = GetMainLight();
                    half4 vertexcolor = i.color;

                    // Lambert Diffuse
                    half4 basecolor    = SAMPLE_TEXTURE2D(_BaseMap,    sampler_BaseMap,    i.uv0);
                    half4 specularMap  = SAMPLE_TEXTURE2D(_SpecularMap, sampler_SpecularMap, i.uv1);
                    half3 N = normalize(i.normalWS);
                    half3 L = normalize(light.direction);
                    half NdotL = saturate(dot(N, L));
                    half halfLambert = saturate(NdotL * 0.5 + 0.5); //半lambert 
                    halfLambert = halfLambert * halfLambert;// * halfLambert; //增加效果

                    // AO 强度调节：1 = 无AO效果，ao值越小遮蔽越强
                    half ao = SAMPLE_TEXTURE2D(_AOMap,sampler_AOMap,i.uv0);
                    ao = lerp(1.0, ao, _AOIntensity);
                    #if _USE_AO_MAP
                        half ambient = halfLambert * ao;
                    #else
                        half ambient = halfLambert;
                    #endif
                    half shadow = (ambient+halfLambert)*0.5;
                    shadow = lerp(shadow,0,step(shadow,0.05));
                    shadow = lerp(shadow,1,step(0.95,shadow));

                    // Ramp色阶阴影
                    half rampU = smoothstep(_ShadowThreshold - _ShadowSoftness,_ShadowThreshold + _ShadowSoftness,halfLambert);
                    half3 RampID = SAMPLE_TEXTURE2D(_RampID,sampler_RampID,i.uv0);
                    half2 rampUV = half2(rampU,GetrampV(RampID));
                    half3 rampColor = SAMPLE_TEXTURE2D(_RampMap,sampler_RampMap,rampUV).rgb;
                    
                    // 最终颜色
                    half3 duffuse = basecolor.rgb * light.color * shadow;
                    half3 color = duffuse;

                    color = lerp(color,lerp(color , color*rampColor , _ShadowIntensity) ,_USE_RAMPMAP);

                    // 高光（大于0.3使用）
                    if(halfLambert > 1- _SpecularRegion)
                    {
                        color.rgb = lerp(color.rgb,lerp(color.rgb , color.rgb+specularMap.a , halfLambert),_SpecularPower);
                    }

                    return half4(color.rgb,basecolor.a);
                }

            ENDHLSL
        }

        pass
        {
            Name "Rim processing"

            Tags
            {
                "LightMode" = "SRPDefaultUnlit"
            }

            Blend One One           // 加法混合：边缘光叠加到主颜色上
            ZWrite Off
            ZTest Always            // 由手动深度比较决定是否为边缘，关闭硬件深度剔除
            Cull Back

            HLSLPROGRAM

                #pragma vertex vert1
                #pragma fragment frag1

                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

                struct RimVaryings
                {
                    float4 positionCS : SV_POSITION; // 偏移后顶点的裁剪空间坐标（片元阶段.xy为像素坐标，.z为设备深度）
                    float3 normalWS   : TEXCOORD0;   // 世界空间法线
                };

                RimVaryings vert1(Attributes i)
                {
                    RimVaryings o;

                    // 沿法线方向偏移顶点，偏移量即边缘光宽度
                    float3 offsetOS = i.positionOS.xyz + i.normalOS * _OffsetMul;
                    o.positionCS = TransformObjectToHClip(offsetOS);

                    // 法线转换到世界空间
                    VertexNormalInputs normalInput = GetVertexNormalInputs(i.normalOS);
                    o.normalWS = normalInput.normalWS;

                    return o;
                }

                half4 frag1(RimVaryings i) : SV_TARGET
                {
                    // 未开启边缘光则直接丢弃
                    if (_UseRimLight < 0.5) discard;

                    // 偏移顶点的屏幕UV与设备深度
                    float2 screenUV   = i.positionCS.xy / _ScreenParams.xy;
                    half   offsetDepth = i.positionCS.z;
                    half   sceneDepth  = SampleSceneDepth(screenUV);

                    // 反转Z下：深度值越大越靠近相机。偏移顶点比场景更近（差值为正）说明该像素落在真实轮廓之外 → 边缘
                    #if UNITY_REVERSED_Z
                        half depthDiff = saturate(offsetDepth - sceneDepth);
                    #else
                        half depthDiff = saturate(sceneDepth - offsetDepth);
                    #endif

                    // 仅受光面显示边缘光
                    Light light = GetMainLight();
                    half3 N = normalize(i.normalWS);
                    half3 L = normalize(light.direction);
                    half  NdotL = saturate(dot(N, L));

                    // 阈值过滤：只有深度差足够大（即真正超出真实轮廓）的地方才出边缘光
                    half rim = smoothstep(_RimThreshold, min(_RimThreshold + 0.05, 1.0), depthDiff) * NdotL;

                    return half4(light.color * rim, rim);
                }

            ENDHLSL
        }
    }
}
