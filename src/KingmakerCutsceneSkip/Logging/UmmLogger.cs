using System;
using UnityModManagerNet;

namespace KingmakerCutsceneSkip.Logging
{
    public sealed class UmmLogger : IModLogger
    {
        private readonly UnityModManager.ModEntry.ModLogger logger;
        private readonly Func<bool> verboseEnabled;

        public UmmLogger(UnityModManager.ModEntry.ModLogger logger, Func<bool> verboseEnabled)
        {
            this.logger = logger ?? throw new ArgumentNullException(nameof(logger));
            this.verboseEnabled = verboseEnabled ?? throw new ArgumentNullException(nameof(verboseEnabled));
        }

        public void Info(string message) => logger.Log(message);

        public void Warning(string message) => logger.Warning(message);

        public void Error(string message) => logger.Error(message);

        public void Exception(string operation, Exception exception) => logger.LogException(operation, exception);

        public void Verbose(string message)
        {
            if (verboseEnabled()) logger.Log("[verbose] " + message);
        }
    }
}
