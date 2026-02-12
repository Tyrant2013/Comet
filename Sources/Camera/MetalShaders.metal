//
//  MetalShaders.metal
//  CameraExample
//
//  Created by zhuangxiaowei on 2026/2/4.
//

#include <metal_stdlib>
using namespace metal;

struct Vertex_In {
    float4 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct Vertex_Out {
    float4 position [[position]];
    float2 texCoord;
};

struct FilterUniform {
    uint type;
    float intensity;
    float param0;
    float param1;
};

constant uint kMaxFilterCount = 16;

struct FilterChainUniform {
    uint count;
    uint padding0;
    uint padding1;
    uint padding2;
    FilterUniform filters[kMaxFilterCount];
};

vertex Vertex_Out vertexFunc(Vertex_In in [[stage_in]]) {
    Vertex_Out out;
    out.position = in.position;
    out.texCoord = in.texCoord;
    return out;
}

fragment float4 fragmentFunc(Vertex_Out in [[stage_in]], texture2d<float> texture [[texture(0)]]) {
    constexpr sampler textureSample(mag_filter::linear, min_filter::linear);
    float4 color = texture.sample(textureSample, in.texCoord);
    return color;
}

float3 applyMonochrome(float3 color, float intensity) {
    float luma = dot(color, float3(0.2126, 0.7152, 0.0722));
    float3 mono = float3(luma, luma, luma);
    return mix(color, mono, clamp(intensity, 0.0, 1.0));
}

float3 applyPolaroid(float3 color, float2 uv, float intensity, float warmth, float fade) {
    float3 warmed = float3(
        color.r + warmth * 0.8,
        color.g + warmth * 0.25,
        color.b - warmth * 0.35
    );
    
    float3 contrasted = (warmed - 0.5) * 1.12 + 0.5;
    float3 faded = mix(contrasted, float3(0.97, 0.94, 0.88), fade);
    
    float2 centered = uv - 0.5;
    float vignette = 1.0 - smoothstep(0.25, 0.72, dot(centered, centered));
    float3 withVignette = faded * mix(1.0, vignette, 0.22);
    
    return mix(color, withVignette, clamp(intensity, 0.0, 1.0));
}

fragment float4 filteredFragmentFunc(Vertex_Out in [[stage_in]],
                                     texture2d<float> texture [[texture(0)]],
                                     constant FilterChainUniform& chain [[buffer(0)]]) {
    constexpr sampler textureSample(mag_filter::linear, min_filter::linear);
    float4 sampled = texture.sample(textureSample, in.texCoord);
    float3 color = sampled.rgb;
    
    uint count = min(chain.count, kMaxFilterCount);
    for (uint i = 0; i < count; i++) {
        FilterUniform f = chain.filters[i];
        switch (f.type) {
            case 1:
                color = applyMonochrome(color, f.intensity);
                break;
            case 2:
                color = applyPolaroid(color, in.texCoord, f.intensity, f.param0, f.param1);
                break;
            default:
                break;
        }
    }
    
    return float4(saturate(color), sampled.a);
}
