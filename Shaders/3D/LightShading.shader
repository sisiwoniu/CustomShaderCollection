Shader "Unlit/LightShading"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        [Toggle]
        _UseAmbient("Use Ambient", float) = 0
        _Ambient("Ambient", Range(0, 1)) = 0
        _DiffuseInt("Diffuse Intensity", Range(0, 1)) = 1
        [NoScaleOffset]
        _SpecularTex("Specular Texture", 2D) = "black" {}
        _SpecularInt("Specular Intensity", Range(0, 1)) = 1
        _SpecularPow("Specular Pow", Range(1, 128)) = 64
        [Toggle]
        _UseReflectCube("Use Reflection Cube", float) = 0
        [NoScaleOffset]
        _ReflectCube("Reflect Cube", Cube) = "white" {}
        _ReflectInt("Reflect Intienty", Range(0, 1)) = 1
        _ReflectExp("Reflect Exp", Range(1, 10)) = 1
        _ReflectLod("Reflect Lod", Range(1, 9)) = 1
        _ReflectMet("Reflect Metallic", Range(0, 1)) = 0
        [Toggle]
        _UseRimLight("Use Rim Light", float) = 0
        _RimLightInt("Rim Light Intensity", Range(0, 1)) = 0
        _RimLightCol("Rim Light Color", Color) = (1, 1, 1, 1)
        _RimLightPow("Rim Light Pow", Range(1, 9)) = 1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "LightModel"="ForwardBase" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma shader_feature _USEREFLECTCUBE_ON
            #pragma shader_feature _USERIMLIGHT_ON
            #pragma shader_feature _USEAMBIENT_ON

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal: NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 normal : TEXCOORD1;
                float4 vertex_world : TEXCOORD2;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _LightColor0;
            float _DiffuseInt;
            sampler2D _SpecularTex;
            float _SpecularInt;
            float _SpecularPow;
            float _Ambient;
            samplerCUBE _ReflectCube;
            float _ReflectInt;
            float _ReflectExp;
            float _ReflectLod;
            float _ReflectMet;
            float4 _RimLightCol;
            float _RimLightInt;
            float _RimLightPow;

            float3 Diffuse(float3 lightColor, float3 normal, float3 lightDir, float diffuseIntensity) 
            {
                return lightColor * diffuseIntensity * max(0, dot(lightDir, normal));
            }

            float3 Specular(float3 baseColor, float3 viewDir, float3 lightDir, float3 normal, float specularInt, float specularPow) 
            {
                float3 halfVec = normalize(viewDir + lightDir);
                return baseColor * specularInt * pow(max(0, dot(halfVec, normal)), specularPow);
            }

            float3 ReflectVec(float3 normal, float3 viewDir) 
            {
                return viewDir - 2.0 * normal * dot(normal, viewDir);
            }

            float3 Reflect(samplerCUBE cube, float3 viewDir, float3 normal, float reflectInt, float reflectExp, float reflectLod) 
            {
                float3 reflectVec = ReflectVec(normal, viewDir);
                float4 cubeCol = texCUBElod(cube, float4(reflectVec, reflectLod));
                return cubeCol.rgb * reflectInt * (cubeCol.a * reflectExp);
            }

            float3 RimLight(float3 viewDir, float3 normal, float rimLightPow) 
            {
                return pow(1 - saturate(dot(viewDir, normal)), rimLightPow);
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.normal = UnityObjectToWorldNormal(v.normal);
                o.vertex_world = mul(unity_ObjectToWorld, v.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);
                float3 normal = i.normal;
                float4 specularTexColor = tex2D(_SpecularTex, i.uv);
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.vertex_world.xyz);
                float3 diffuse = Diffuse(_LightColor0, normal, _WorldSpaceLightPos0, _DiffuseInt);
                float3 specular = Specular(specularTexColor, viewDir, _WorldSpaceLightPos0, normal, _SpecularInt, _SpecularPow);
                #if _USEAMBIENT_ON
                    float3 ambient = UNITY_LIGHTMODEL_AMBIENT * _Ambient;
                    col.rgb += ambient;
                #endif
                
                col.rgb *= diffuse + specular;

                #if _USEREFLECTCUBE_ON
                    float3 reflect = Reflect(_ReflectCube, -viewDir, normal, _ReflectInt, _ReflectExp, _ReflectLod);
                    col.rgb *= reflect + _ReflectMet;
                #endif
                
                #if _USERIMLIGHT_ON
                    float3 rimLight = RimLight(viewDir, normal, _RimLightPow);
                    col.rgb += rimLight * _RimLightInt * _RimLightCol.rgb;
                #endif
                
                return col;
            }
            ENDCG
        }
    }
}
