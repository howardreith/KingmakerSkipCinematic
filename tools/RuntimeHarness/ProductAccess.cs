using System;
using System.Linq;
using System.Reflection;
using System.Runtime.CompilerServices;
using Harmony12;
using KingmakerCutsceneSkip.Core;
using Newtonsoft.Json.Linq;

namespace KingmakerCutsceneSkip.RuntimeHarness
{
    /// <summary>
    /// The harness's only door into the product. Every member that touches a product type lives in a NoInlining
    /// "Core" method that is JIT-compiled only after IsLoaded confirmed the product assembly is present, so the harness
    /// also runs (as a pure observer) when Cutscene Skip is removed for mod-absent baselines.
    /// </summary>
    internal static class ProductAccess
    {
        public const string ProductId = "KingmakerCutsceneSkip";

        private static bool? loaded;
        private static object subscribedController;

        public static bool IsLoaded
        {
            get
            {
                if (!loaded.HasValue) loaded = AppDomain.CurrentDomain.GetAssemblies().Any(assembly => assembly.GetName().Name == ProductId);
                return loaded.Value;
            }
        }

        public static string Phase => IsLoaded ? PhaseCore() : "absent";

        public static bool IsIdle => !IsLoaded || PhaseCore() == "Idle";

        public static bool IsSkipping => IsLoaded && IsSkippingCore();

        public static object LastReportIdentity => IsLoaded ? LastReportCore() : null;

        public static JObject LastReportJson => IsLoaded ? LastReportJsonCore() : null;

        public static bool TryStart(out string declineReason)
        {
            declineReason = "product absent";
            return IsLoaded && TryStartCore(out declineReason);
        }

        public static bool TryCancel() => IsLoaded && TryCancelCore();

        public static void SubscribeReports(Action<JObject> onReport)
        {
            if (IsLoaded) SubscribeCore(onReport);
        }

        public static JObject Identity()
        {
            return IsLoaded ? IdentityCore() : new JObject { ["productLoaded"] = false };
        }

        public static void InstallFaultInjection(HarmonyInstance harmony)
        {
            if (IsLoaded) InstallFaultInjectionCore(harmony);
        }

        [MethodImpl(MethodImplOptions.NoInlining)]
        private static CutsceneSkipController ControllerCore() => KingmakerCutsceneSkip.Main.Runtime?.Controller;

        [MethodImpl(MethodImplOptions.NoInlining)]
        private static string PhaseCore() => ControllerCore()?.Phase.ToString() ?? "unavailable";

        [MethodImpl(MethodImplOptions.NoInlining)]
        private static bool IsSkippingCore() => ControllerCore()?.IsSkipping ?? false;

        [MethodImpl(MethodImplOptions.NoInlining)]
        private static object LastReportCore() => ControllerCore()?.LastReport;

        [MethodImpl(MethodImplOptions.NoInlining)]
        private static JObject LastReportJsonCore()
        {
            SkipOperationReport report = ControllerCore()?.LastReport;
            return report == null ? null : JObject.FromObject(report, new Newtonsoft.Json.JsonSerializer());
        }

        [MethodImpl(MethodImplOptions.NoInlining)]
        private static bool TryStartCore(out string declineReason)
        {
            CutsceneSkipController controller = ControllerCore();
            bool started = controller != null && controller.TryStart();
            declineReason = controller == null ? "controller unavailable" : controller.LastDeclineReason.ToString();
            return started;
        }

        [MethodImpl(MethodImplOptions.NoInlining)]
        private static bool TryCancelCore() => ControllerCore()?.TryCancel() ?? false;

        [MethodImpl(MethodImplOptions.NoInlining)]
        private static void SubscribeCore(Action<JObject> onReport)
        {
            CutsceneSkipController controller = ControllerCore();
            if (controller == null || ReferenceEquals(controller, subscribedController)) return;
            controller.OperationEnded += report => onReport(JObject.FromObject(report, new Newtonsoft.Json.JsonSerializer()));
            subscribedController = controller;
        }

        [MethodImpl(MethodImplOptions.NoInlining)]
        private static JObject IdentityCore()
        {
            Assembly assembly = typeof(ProductMetadata).Assembly;
            return new JObject
            {
                ["productLoaded"] = true,
                ["productVersion"] = ProductMetadata.Version,
                ["productAssembly"] = assembly.Location,
                ["productMvid"] = assembly.ManifestModule.ModuleVersionId.ToString()
            };
        }

        [MethodImpl(MethodImplOptions.NoInlining)]
        private static void InstallFaultInjectionCore(HarmonyInstance harmony)
        {
            Type probe = typeof(ProductMetadata).Assembly.GetType("KingmakerCutsceneSkip.Integration.KingmakerGameStateProbe", true);
            MethodInfo method = probe.GetMethod("GetBoundary", BindingFlags.Instance | BindingFlags.Public);
            harmony.Patch(method, new HarmonyMethod(typeof(FaultInjection).GetMethod("Prefix", BindingFlags.Static | BindingFlags.NonPublic)), null);
        }
    }
}
