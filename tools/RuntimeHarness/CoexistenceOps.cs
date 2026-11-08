using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using Kingmaker;
using Kingmaker.Blueprints;
using Kingmaker.Blueprints.Items;
using Kingmaker.Blueprints.Items.Ecnchantments;
using Kingmaker.Items;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityModManagerNet;

namespace KingmakerCutsceneSkip.RuntimeHarness
{
    /// <summary>
    /// Behavioural checks of other mods and of the UMM panel, for loader-compatibility evidence. Third-party mods are
    /// reached by reflection so the harness has no compile-time dependency on them; a missing member fails the step.
    /// </summary>
    internal static class CoexistenceOps
    {
        private const BindingFlags Any = BindingFlags.Static | BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic;
        private const string CraftMagicItemsPrefix = "#CraftMagicItems";

        /// <summary>
        /// Upgrades one mundane weapon through Craft Magic Items' own code: its GUID builder, its custom-blueprint patches
        /// on ResourcesLibrary and its CraftItem. Returns the custom blueprint GUID.
        /// </summary>
        public static string CraftMagicItemsUpgrade(string enchantmentName, JObject evidence)
        {
            Assembly assembly = AppDomain.CurrentDomain.GetAssemblies().FirstOrDefault(a => a.GetName().Name == "CraftMagicItems");
            if (assembly == null) throw new InvalidOperationException("Craft Magic Items is not loaded");
            Type main = assembly.GetType("CraftMagicItems.Main", true);
            object patcher = main.GetField("blueprintPatcher", Any).GetValue(null);
            if (patcher == null) throw new InvalidOperationException("Craft Magic Items has no blueprint patcher (mod not enabled?)");

            ItemEntityWeapon weapon = Game.Instance.Player.Inventory.OfType<ItemEntityWeapon>().FirstOrDefault(item =>
                item.Blueprint != null && item.Blueprint.Enchantments.Count == 0 && !item.Blueprint.AssetGuid.Contains(CraftMagicItemsPrefix));
            if (weapon == null) throw new InvalidOperationException("no mundane weapon in the fixture inventory");

            BlueprintWeaponEnchantment enchantment = ResourcesLibrary.GetBlueprints<BlueprintWeaponEnchantment>()
                .FirstOrDefault(candidate => candidate != null && string.Equals(candidate.name, enchantmentName, StringComparison.Ordinal));
            if (enchantment == null) throw new InvalidOperationException("no weapon enchantment named " + enchantmentName);

            MethodInfo build = patcher.GetType().GetMethod("BuildCustomRecipeItemGuid", Any);
            ParameterInfo[] parameters = build.GetParameters();
            object[] arguments = new object[parameters.Length];
            for (int index = 0; index < parameters.Length; index++) arguments[index] = parameters[index].DefaultValue;
            arguments[0] = weapon.Blueprint.AssetGuid;
            arguments[1] = (IEnumerable<string>)new[] { enchantment.AssetGuid };
            string guid = (string)build.Invoke(patcher, arguments);

            BlueprintItem custom = ResourcesLibrary.TryGetBlueprint(guid) as BlueprintItem;
            if (custom == null) throw new InvalidOperationException("Craft Magic Items did not resolve the custom blueprint " + guid);
            ItemEntity result = custom.CreateEntity();
            main.GetMethod("CraftItem", Any).Invoke(null, new object[] { result, weapon });

            evidence["cmiBaseItem"] = weapon.Blueprint.name;
            evidence["cmiEnchantment"] = enchantment.name;
            evidence["cmiCustomGuid"] = guid;
            CraftMagicItemsVerify(guid, enchantment.AssetGuid, evidence, "cmiAfterCraft");
            return guid;
        }

        /// <summary>The custom item is in the inventory, resolves to its blueprint and carries the enchantment.</summary>
        public static void CraftMagicItemsVerify(string guid, string enchantmentGuid, JObject evidence, string label)
        {
            ItemEntity item = Game.Instance.Player.Inventory.FirstOrDefault(candidate => candidate?.Blueprint != null && candidate.Blueprint.AssetGuid == guid);
            if (item == null) throw new InvalidOperationException("custom item is not in the inventory: " + guid);
            string[] enchantments = item.Enchantments.Select(enchantment => enchantment.Blueprint.AssetGuid).ToArray();
            evidence[label] = new JObject
            {
                ["item"] = item.Blueprint.name, ["guid"] = guid, ["enchantments"] = new JArray(enchantments.Cast<object>().ToArray()),
                ["enchantmentValue"] = item.EnchantmentValue
            };
            if (!enchantments.Contains(enchantmentGuid)) throw new InvalidOperationException("custom item lacks enchantment " + enchantmentGuid);
        }

        /// <summary>Reads a blueprint member by name, for mods whose effect is a changed blueprint value.</summary>
        public static string ProbeBlueprint(string typeName, string blueprintName, string memberName)
        {
            BlueprintScriptableObject blueprint = ResourcesLibrary.GetBlueprints<BlueprintScriptableObject>()
                .FirstOrDefault(candidate => candidate != null && candidate.GetType().Name == typeName && string.Equals(candidate.name, blueprintName, StringComparison.Ordinal));
            if (blueprint == null) throw new InvalidOperationException("no " + typeName + " named " + blueprintName);
            object value = blueprint.GetType().GetProperty(memberName, Any)?.GetValue(blueprint, null) ?? blueprint.GetType().GetField(memberName, Any)?.GetValue(blueprint);
            return Convert.ToString(value, System.Globalization.CultureInfo.InvariantCulture);
        }

        /// <summary>
        /// Opens the UMM window, draws the product's registered settings GUI in a real IMGUI pass, and saves its settings.
        /// </summary>
        public static SettingsDrawProbe BeginPanelCheck(bool injectRenderFault)
        {
            PanelFaultWatch.Begin(injectRenderFault);
            UnityModManager.UI.Instance?.ToggleWindow(true);
            GameObject holder = new GameObject("KmcsSettingsDrawProbe");
            UnityEngine.Object.DontDestroyOnLoad(holder);
            return holder.AddComponent<SettingsDrawProbe>();
        }

        public static string FinishPanelCheck(SettingsDrawProbe probe)
        {
            UnityModManager.ModEntry product = UnityModManager.FindMod(ProductAccess.ProductId);
            string failure = probe.Failure ?? PanelFaultWatch.LoggedFailure;
            int draws = probe.Draws;
            int repaints = probe.Repaints;
            UnityEngine.Object.Destroy(probe.gameObject);
            UnityModManager.UI.Instance?.ToggleWindow(false);
            try
            {
                if (failure != null) throw new InvalidOperationException("settings GUI failed: " + failure);
                if (draws == 0 || repaints == 0) throw new InvalidOperationException("settings GUI never completed a repaint (draws " + draws + ", repaints " + repaints + ")");
                string roundTrip = ProductAccess.VerifySettingsRoundTrip(product);
                if (PanelFaultWatch.LoggedFailure != null) throw new InvalidOperationException("saving settings failed: " + PanelFaultWatch.LoggedFailure);
                string settings = Path.Combine(product.Path, "Settings.xml");
                if (!File.Exists(settings)) throw new InvalidOperationException("settings were not written: " + settings);
                return "draws=" + draws + "; repaints=" + repaints + "; " + roundTrip;
            }
            finally
            {
                PanelFaultWatch.End();
            }
        }
    }

    /// <summary>
    /// The product's GUI callbacks catch and log their own exceptions, so a failure never reaches the caller. While a panel
    /// check runs this records what the product logs for its settings callbacks, and can make the render throw on purpose.
    /// Installed by the harness only; the product's own handling is unchanged.
    /// </summary>
    internal static class PanelFaultWatch
    {
        private static bool watching;
        private static bool throwOnDraw;

        public static string LoggedFailure { get; private set; }

        public static void Begin(bool injectRenderFault)
        {
            LoggedFailure = null;
            watching = true;
            throwOnDraw = injectRenderFault;
        }

        public static void End()
        {
            watching = false;
            throwOnDraw = false;
        }

        private static void LogExceptionPrefix(string __0, Exception __1)
        {
            if (watching && LoggedFailure == null && __0 != null && __0.IndexOf("Cutscene Skip settings", StringComparison.Ordinal) >= 0)
            {
                LoggedFailure = __0 + ": " + __1;
            }
        }

        private static void DrawPrefix()
        {
            if (throwOnDraw) throw new InvalidOperationException("harness injected settings render failure");
        }
    }

    /// <summary>Draws the product's OnGUI on an ordinary IMGUI pass. A pass counts only if the product logged no failure during it.</summary>
    internal sealed class SettingsDrawProbe : MonoBehaviour
    {
        public int Draws { get; private set; }

        public int Repaints { get; private set; }

        public string Failure { get; private set; }

        private void OnGUI()
        {
            UnityModManager.ModEntry product = UnityModManager.FindMod(ProductAccess.ProductId);
            if (product?.OnGUI == null)
            {
                Failure = "product has no OnGUI";
                return;
            }

            try
            {
                GUILayout.BeginArea(new Rect(20, 20, 600, 200));
                product.OnGUI(product);
                GUILayout.EndArea();
                if (PanelFaultWatch.LoggedFailure != null) return;
                Draws++;
                if (Event.current.type == EventType.Repaint) Repaints++;
            }
            catch (Exception exception)
            {
                if (exception is ExitGUIException) throw;
                Failure = exception.ToString();
            }
        }
    }
}
