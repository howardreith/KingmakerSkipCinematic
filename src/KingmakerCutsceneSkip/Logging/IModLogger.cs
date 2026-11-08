using System;

namespace KingmakerCutsceneSkip.Logging
{
    public interface IModLogger
    {
        void Info(string message);
        void Warning(string message);
        void Error(string message);
        void Exception(string operation, Exception exception);
        void Verbose(string message);
    }
}
