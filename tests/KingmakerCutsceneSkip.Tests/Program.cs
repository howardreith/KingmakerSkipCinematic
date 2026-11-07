using System;
using System.IO;
using System.Linq;
using System.Reflection;

namespace KingmakerCutsceneSkip.Tests
{
    /// <summary>
    /// Dependency-free deterministic runner: every public static parameterless method on a type whose name ends in
    /// "Tests" is a test. Game and UMM assemblies resolve from KMCS_TEST_REFERENCE_DIRS (set by scripts/Test.ps1).
    /// </summary>
    internal static class Program
    {
        private static int Main()
        {
            AppDomain.CurrentDomain.AssemblyResolve += ResolveConfiguredReference;
            MethodInfo[] tests = typeof(Program).Assembly.GetTypes()
                .Where(type => type.Name.EndsWith("Tests", StringComparison.Ordinal))
                .SelectMany(type => type.GetMethods(BindingFlags.Public | BindingFlags.Static))
                .Where(method => method.GetParameters().Length == 0 && method.ReturnType == typeof(void))
                .OrderBy(method => method.DeclaringType.Name, StringComparer.Ordinal)
                .ThenBy(method => method.Name, StringComparer.Ordinal)
                .ToArray();

            int failed = 0;
            foreach (MethodInfo test in tests)
            {
                string name = test.DeclaringType.Name + "." + test.Name;
                try
                {
                    test.Invoke(null, null);
                    Console.WriteLine("PASS " + name);
                }
                catch (TargetInvocationException exception)
                {
                    failed++;
                    Console.WriteLine("FAIL " + name + ": " + exception.InnerException);
                }
            }

            Console.WriteLine("RESULT total=" + tests.Length + " passed=" + (tests.Length - failed) + " failed=" + failed);
            return failed == 0 ? 0 : 1;
        }

        private static Assembly ResolveConfiguredReference(object sender, ResolveEventArgs args)
        {
            string directories = Environment.GetEnvironmentVariable("KMCS_TEST_REFERENCE_DIRS");
            if (string.IsNullOrWhiteSpace(directories)) return null;
            string fileName = new AssemblyName(args.Name).Name + ".dll";
            foreach (string directory in directories.Split(new[] { Path.PathSeparator }, StringSplitOptions.RemoveEmptyEntries))
            {
                string candidate = Path.Combine(directory, fileName);
                if (File.Exists(candidate)) return Assembly.LoadFrom(candidate);
            }

            return null;
        }
    }
}
