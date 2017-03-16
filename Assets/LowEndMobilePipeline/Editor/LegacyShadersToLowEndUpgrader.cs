﻿using System.Collections.Generic;
using UnityEditor.Experimental.Rendering;
using UnityEditor;

public class LegacyShadersToLowEndUpgrader : MaterialUpgrader
{
    private struct UpgradeParams
    {
        public float blendMode;
        public float specularSource;
        public float glosinessSource;
        public float reflectionSource;
    }

    private static class SupportedUpgradeParams
    {
        static public UpgradeParams diffuseOpaque = new UpgradeParams()
        {
            blendMode = (float)LowendMobilePipelineMaterialEditor.BlendMode.Opaque,
            specularSource = (float)LowendMobilePipelineMaterialEditor.SpecularSource.NoSpecular,
            glosinessSource = (float)LowendMobilePipelineMaterialEditor.GlossinessSource.BaseAlpha,
            reflectionSource = (float)LowendMobilePipelineMaterialEditor.ReflectionSource.NoReflection
        };

        static public UpgradeParams specularOpaque = new UpgradeParams()
        {
            blendMode = (float)LowendMobilePipelineMaterialEditor.BlendMode.Opaque,
            specularSource = (float)LowendMobilePipelineMaterialEditor.SpecularSource.SpecularTextureAndColor,
            glosinessSource = (float)LowendMobilePipelineMaterialEditor.GlossinessSource.BaseAlpha,
            reflectionSource = (float)LowendMobilePipelineMaterialEditor.ReflectionSource.NoReflection
        };

        static public UpgradeParams diffuseAlpha = new UpgradeParams()
        {
            blendMode = (float)LowendMobilePipelineMaterialEditor.BlendMode.Alpha,
            specularSource = (float)LowendMobilePipelineMaterialEditor.SpecularSource.NoSpecular,
            glosinessSource = (float)LowendMobilePipelineMaterialEditor.GlossinessSource.SpecularAlpha,
            reflectionSource = (float)LowendMobilePipelineMaterialEditor.ReflectionSource.NoReflection
        };

        static public UpgradeParams specularAlpha = new UpgradeParams()
        {
            blendMode = (float)LowendMobilePipelineMaterialEditor.BlendMode.Alpha,
            specularSource = (float)LowendMobilePipelineMaterialEditor.SpecularSource.SpecularTextureAndColor,
            glosinessSource = (float)LowendMobilePipelineMaterialEditor.GlossinessSource.SpecularAlpha,
            reflectionSource = (float)LowendMobilePipelineMaterialEditor.ReflectionSource.NoReflection
        };

        static public UpgradeParams diffuseAlphaCutout = new UpgradeParams()
        {
            blendMode = (float)LowendMobilePipelineMaterialEditor.BlendMode.Cutout,
            specularSource = (float)LowendMobilePipelineMaterialEditor.SpecularSource.NoSpecular,
            glosinessSource = (float)LowendMobilePipelineMaterialEditor.GlossinessSource.SpecularAlpha,
            reflectionSource = (float)LowendMobilePipelineMaterialEditor.ReflectionSource.NoReflection
        };

        static public UpgradeParams specularAlphaCutout = new UpgradeParams()
        {
            blendMode = (float)LowendMobilePipelineMaterialEditor.BlendMode.Cutout,
            specularSource = (float)LowendMobilePipelineMaterialEditor.SpecularSource.SpecularTextureAndColor,
            glosinessSource = (float)LowendMobilePipelineMaterialEditor.GlossinessSource.SpecularAlpha,
            reflectionSource = (float)LowendMobilePipelineMaterialEditor.ReflectionSource.NoReflection
        };

        static public UpgradeParams diffuseCubemap = new UpgradeParams()
        {
            blendMode = (float)LowendMobilePipelineMaterialEditor.BlendMode.Opaque,
            specularSource = (float)LowendMobilePipelineMaterialEditor.SpecularSource.NoSpecular,
            glosinessSource = (float)LowendMobilePipelineMaterialEditor.GlossinessSource.BaseAlpha,
            reflectionSource = (float)LowendMobilePipelineMaterialEditor.ReflectionSource.Cubemap
        };

        static public UpgradeParams specularCubemap = new UpgradeParams()
        {
            blendMode = (float)LowendMobilePipelineMaterialEditor.BlendMode.Opaque,
            specularSource = (float)LowendMobilePipelineMaterialEditor.SpecularSource.SpecularTextureAndColor,
            glosinessSource = (float)LowendMobilePipelineMaterialEditor.GlossinessSource.BaseAlpha,
            reflectionSource = (float)LowendMobilePipelineMaterialEditor.ReflectionSource.Cubemap
        };

        static public UpgradeParams specularCubemapAlpha = new UpgradeParams()
        {
            blendMode = (float)LowendMobilePipelineMaterialEditor.BlendMode.Alpha,
            specularSource = (float)LowendMobilePipelineMaterialEditor.SpecularSource.SpecularTextureAndColor,
            glosinessSource = (float)LowendMobilePipelineMaterialEditor.GlossinessSource.BaseAlpha,
            reflectionSource = (float)LowendMobilePipelineMaterialEditor.ReflectionSource.Cubemap
        };
    }

    [MenuItem("RenderPipeline/LowEndMobilePipeline/Material Upgraders/Upgrade Legacy Materials to LowEndMobile - Selection", false, 3)]
    public static void UpgradeMaterialsToLDSelection()
    {
        List<MaterialUpgrader> materialUpgraders = new List<MaterialUpgrader>();
        GetUpgraders(ref materialUpgraders);

        MaterialUpgrader.UpgradeSelection(materialUpgraders, "Upgrade to LD Materials");
    }

    [MenuItem("RenderPipeline/LowEndMobilePipeline/Material Upgraders/Upgrade Legacy Materials to LowEndMobile - Project", false, 4)]
    public static void UpgradeMaterialsToLDProject()
    {
        List<MaterialUpgrader> materialUpgraders = new List<MaterialUpgrader>();
        GetUpgraders(ref materialUpgraders);

        MaterialUpgrader.UpgradeProjectFolder(materialUpgraders, "Upgrade to LD Materials");
    }

    // TODO: Replace this logic with AssignNewShaderToMaterial
    private static void GetUpgraders(ref List<MaterialUpgrader> materialUpgraders)
    {
        /////////////////////////////////////
        // Legacy Shaders upgraders         /
        /////////////////////////////////////
        materialUpgraders.Add(new LegacyShadersToLowEndUpgrader("Legacy Shaders/Diffuse", SupportedUpgradeParams.diffuseOpaque));
        materialUpgraders.Add(new LegacyShadersToLowEndUpgrader("Legacy Shaders/Specular", SupportedUpgradeParams.specularOpaque));
        materialUpgraders.Add(new LegacyShadersToLowEndUpgrader("Legacy Shaders/Bumped Diffuse", SupportedUpgradeParams.diffuseOpaque));
        materialUpgraders.Add(new LegacyShadersToLowEndUpgrader("Legacy Shaders/Bumped Specular", SupportedUpgradeParams.specularOpaque));

        // TODO: option to use environment map as texture or use reflection probe
        materialUpgraders.Add(new LegacyShadersToLowEndUpgrader("Legacy Shaders/Reflective/Bumped Diffuse", SupportedUpgradeParams.diffuseCubemap));
        materialUpgraders.Add(new LegacyShadersToLowEndUpgrader("Legacy Shaders/Reflective/Bumped Specular", SupportedUpgradeParams.specularOpaque));
        materialUpgraders.Add(new LegacyShadersToLowEndUpgrader("Legacy Shaders/Reflective/Diffuse", SupportedUpgradeParams.diffuseCubemap));
        materialUpgraders.Add(new LegacyShadersToLowEndUpgrader("Legacy Shaders/Reflective/Specular", SupportedUpgradeParams.specularOpaque));

        // Self-Illum upgrade still not supported
        //materialUpgraders.Add(new LegacyShaderToLowEndUpgrader("Legacy Shaders/Self-Illum/Bumped Specular"));

        // Alpha Blended
        materialUpgraders.Add(new LegacyShadersToLowEndUpgrader("Legacy Shaders/Transparent/Diffuse", SupportedUpgradeParams.diffuseAlpha));
        materialUpgraders.Add(new LegacyShadersToLowEndUpgrader("Legacy Shaders/Transparent/Specular", SupportedUpgradeParams.specularAlpha));
        materialUpgraders.Add(new LegacyShadersToLowEndUpgrader("Legacy Shaders/Transparent/Bumped Diffuse", SupportedUpgradeParams.diffuseAlpha));
        materialUpgraders.Add(new LegacyShadersToLowEndUpgrader("Legacy Shaders/Transparent/Bumped Specular", SupportedUpgradeParams.specularAlpha));

        // Cutout
        materialUpgraders.Add(new LegacyShadersToLowEndUpgrader("Legacy Shaders/Transparent/Cutout/Diffuse", SupportedUpgradeParams.diffuseAlphaCutout));
        materialUpgraders.Add(new LegacyShadersToLowEndUpgrader("Legacy Shaders/Transparent/Cutout/Specular", SupportedUpgradeParams.specularAlphaCutout));
        materialUpgraders.Add(new LegacyShadersToLowEndUpgrader("Legacy Shaders/Transparent/Cutout/Bumped Diffuse", SupportedUpgradeParams.diffuseAlphaCutout));
        materialUpgraders.Add(new LegacyShadersToLowEndUpgrader("Legacy Shaders/Transparent/Cutout/Bumped Specular", SupportedUpgradeParams.specularAlphaCutout));

        /////////////////////////////////////
        // Reflective Shader Upgraders      /
        /////////////////////////////////////
        materialUpgraders.Add(new LegacyShadersToLowEndUpgrader("Reflective/Diffuse Reflection Spec", SupportedUpgradeParams.specularCubemap));
        materialUpgraders.Add(new LegacyShadersToLowEndUpgrader("Reflective/Diffuse Reflection Spec Transp", SupportedUpgradeParams.specularCubemapAlpha));

        /////////////////////////////////////
        // Mobile Upgraders                 /
        /////////////////////////////////////
        materialUpgraders.Add(new LegacyShadersToLowEndUpgrader("Mobile/Diffuse", SupportedUpgradeParams.diffuseOpaque));
        materialUpgraders.Add(new LegacyShadersToLowEndUpgrader("Mobile/Bumped Specular", SupportedUpgradeParams.specularOpaque));
        materialUpgraders.Add(new LegacyShadersToLowEndUpgrader("Mobile/Bumped Specular(1 Directional Light)", SupportedUpgradeParams.specularOpaque));
        materialUpgraders.Add(new LegacyShadersToLowEndUpgrader("Mobile/Bumped Diffuse", SupportedUpgradeParams.diffuseOpaque));
        materialUpgraders.Add(new LegacyShadersToLowEndUpgrader("Mobile/Unlit (Supports Lightmap)", SupportedUpgradeParams.diffuseOpaque));
        materialUpgraders.Add(new LegacyShadersToLowEndUpgrader("Mobile/VertexLit", SupportedUpgradeParams.specularOpaque));
    }

    LegacyShadersToLowEndUpgrader(string oldShaderName, UpgradeParams upgraderParams)
    {
        RenameShader(oldShaderName, "ScriptableRenderPipeline/LowEndMobile");
        SetNewFloatProperty("_Mode", upgraderParams.blendMode);
        SetNewFloatProperty("_SpecSource", upgraderParams.specularSource);
        SetNewFloatProperty("_GlossinessSource", upgraderParams.glosinessSource);
        SetNewFloatProperty("_ReflectionSource", upgraderParams.reflectionSource);
    }
}