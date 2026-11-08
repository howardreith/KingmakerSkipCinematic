using System;
using System.Globalization;
using System.IO;
using System.Linq;
using Kingmaker;
using Kingmaker.AreaLogic.Cutscenes;
using Kingmaker.DialogSystem.Blueprints;
using Kingmaker.EntitySystem.Entities;
using Kingmaker.EntitySystem.Persistence;
using Kingmaker.UnitLogic.Commands;
using Kingmaker.PubSubSystem;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityModManagerNet;

namespace KingmakerCutsceneSkip.RuntimeHarness
{
    /// <summary>Executes the request's steps one per frame-poll, after loading the requested save from the main menu.</summary>
    internal sealed class ScenarioRunner
    {
        private enum Stage { WaitMainMenu, LoadingSave, Settling, Steps, Finished }

        private enum StepStatus { Running, Done, Failed }

        private readonly HarnessRequest request;
        private readonly EvidenceRecorder recorder;
        private readonly JObject result;
        private readonly double startedAt;
        private Stage stage = Stage.WaitMainMenu;
        private double stageStartedAt;
        private int stepIndex;
        private bool stepBegun;
        private double stepStartedAt;
        private double conditionMetAt;
        private int keyEventsSent;
        /// <summary>StartedOperations when input was last sent (pressKey, skipDirect, markOperations).</summary>
        private int operationsAtMark;
        private int operationsAtStepBegin;
        private int autoplaySkipPresses;
        private int autoplaySkipRefused;
        private string stepFailure;
        private int quitCountdown = -1;

        public ScenarioRunner(HarnessRequest request, EvidenceRecorder recorder, JObject result)
        {
            this.request = request;
            this.recorder = recorder;
            this.result = result;
            startedAt = Time.realtimeSinceStartup;
            stageStartedAt = startedAt;
            EventBus.Subscribe(recorder);
        }

        public bool IsFinished => stage == Stage.Finished;

        private double Now => Time.realtimeSinceStartup;

        public void Tick()
        {
            if (quitCountdown >= 0)
            {
                if (quitCountdown-- == 0) Application.Quit();
                return;
            }

            if (stage == Stage.Finished) return;
            if (pendingKeyUp != null && Now >= pendingKeyUpAt)
            {
                NativeKeyboard.Send(pendingKeyUp, false);
                recorder.Event("keyUp", pendingKeyUp);
                pendingKeyUp = null;
            }

            SubscribeToSkipReports();
            recorder.Tick();

            if (Now - startedAt > request.TimeoutSeconds)
            {
                Finish(false, "run timeout after " + request.TimeoutSeconds + "s at " + CurrentStepName());
                return;
            }

            switch (stage)
            {
                case Stage.WaitMainMenu:
                    TickWaitMainMenu();
                    break;
                case Stage.LoadingSave:
                    if (!LoadingProcess.Instance.IsLoadingInProcess && Game.Instance.CurrentlyLoadedArea != null &&
                        Game.Instance.Player != null && Game.Instance.CurrentMode != Kingmaker.GameModes.GameModeType.None)
                    {
                        Enter(Stage.Settling);
                        recorder.Event("saveLoaded", Game.Instance.CurrentlyLoadedArea.name);
                    }

                    break;
                case Stage.Settling:
                    if (Now - stageStartedAt >= 1.0) Enter(Stage.Steps);
                    break;
                case Stage.Steps:
                    TickSteps();
                    break;
            }
        }

        private void TickWaitMainMenu()
        {
            MainMenu menu = UnityEngine.Object.FindObjectOfType<MainMenu>();
            if (menu == null || LoadingProcess.Instance.IsLoadingInProcess || Now - stageStartedAt < 3.0) return;

            UnityModManager.UI.Instance?.ToggleWindow(false);
            string path = Path.Combine(Game.Instance.SaveManager.SavePath, request.Save);
            SaveInfo save = Game.Instance.SaveManager.LoadZipSave(path);
            if (save == null)
            {
                Finish(false, "fixture save could not be read: " + path);
                return;
            }

            recorder.Event("loadSave", request.Save);
            menu.LoadGame(save);
            Enter(Stage.LoadingSave);
        }

        private void TickSteps()
        {
            if (stepIndex >= request.Steps.Count)
            {
                Finish(true, null);
                return;
            }

            HarnessStep step = request.Steps[stepIndex];
            if (!stepBegun)
            {
                stepBegun = true;
                stepStartedAt = Now;
                conditionMetAt = double.NaN;
                keyEventsSent = 0;
                stepFailure = null;
                operationsAtStepBegin = ProductAccess.StartedOperations;
                autoplaySkipPresses = 0;
                autoplaySkipRefused = 0;
                recorder.Event("stepBegin", step.ToString());
            }

            StepStatus status;
            try
            {
                status = Poll(step);
            }
            catch (Exception exception)
            {
                stepFailure = exception.ToString();
                status = StepStatus.Failed;
            }

            if (status == StepStatus.Running && Now - stepStartedAt > step.TimeoutSeconds)
            {
                stepFailure = "step timeout after " + step.TimeoutSeconds + "s";
                status = StepStatus.Failed;
            }

            if (status == StepStatus.Running) return;
            if (status == StepStatus.Failed)
            {
                recorder.Event("stepFailed", step + ": " + stepFailure);
                if (!step.Optional)
                {
                    recorder.Screenshot("failure_" + stepIndex);
                    WriteSnapshot("failure");
                    Finish(false, step + ": " + stepFailure);
                    return;
                }
            }
            else
            {
                recorder.Event("stepDone", step.ToString());
            }

            stepIndex++;
            stepBegun = false;
        }

        private StepStatus Poll(HarnessStep step)
        {
            Game game = Game.Instance;
            switch (step.Op)
            {
                case "wait":
                    return Now - stepStartedAt >= step.Seconds ? StepStatus.Done : StepStatus.Running;

                case "waitCutscene":
                    return Settled(game.CurrentMode == Kingmaker.GameModes.GameModeType.Cutscene && HasControllingCutscene(step.Match), step.Seconds);

                case "waitMode":
                    return Settled(string.Equals(game.CurrentMode.ToString(), step.Mode, StringComparison.Ordinal), step.Seconds);

                case "waitNotMode":
                    return Settled(!string.Equals(game.CurrentMode.ToString(), step.Mode, StringComparison.Ordinal), step.Seconds);

                case "pressKey":
                    return PressKey(step);

                case "skipDirect":
                    MarkOperations("skipDirect");
                    return Fail(!ProductAccess.TryStart(out string declineReason), "skip declined: " + declineReason);

                case "applyBuff":
                    return ApplyBuff(game, step);

                case "markOperations":
                    MarkOperations(step.Label);
                    return StepStatus.Done;

                case "cancelDirect":
                    return Fail(!ProductAccess.TryCancel(), "nothing to cancel");

                case "waitSkipActive":
                    return ProductAccess.IsSkipping && ProductAccess.StartedOperations > operationsAtMark ? StepStatus.Done : StepStatus.Running;

                case "waitSkipPhase":
                    return string.Equals(ProductAccess.Phase, step.Mode, StringComparison.Ordinal) ? StepStatus.Done : StepStatus.Running;

                case "waitSkipIdle":
                    return WaitSkipIdle(step);

                case "expectNoSkip":
                    return Fail(!ProductAccess.IsIdle || ProductAccess.StartedOperations != operationsAtMark,
                        "a skip started after the last input mark (started " + (ProductAccess.StartedOperations - operationsAtMark) + ")");

                case "snapshot":
                    WriteSnapshot(step.Label);
                    recorder.Screenshot("snapshot_" + step.Label);
                    return StepStatus.Done;

                case "screenshot":
                    recorder.Screenshot("shot_" + step.Label);
                    return StepStatus.Done;

                case "captureFor":
                    recorder.ExtendCapture(step.Seconds);
                    return StepStatus.Done;

                case "moveTo":
                    return MoveMainCharacter(game, step);

                case "interactNearest":
                    return InteractNearest(game, step);

                case "useAreaTransition":
                    return UseNearestAreaTransition(game);

                case "saveGame":
                    if (double.IsNaN(conditionMetAt))
                    {
                        conditionMetAt = Now;
                        saveCompleted = false;
                        SaveInfo created = game.SaveManager.CreateNewSave(step.Label);
                        recorder.Event("saveGame", created.FolderName);
                        result["savedGame"] = created.FolderName;
                        game.SaveGame(created, () => saveCompleted = true);
                    }

                    return saveCompleted && !game.SaveManager.CommitInProgress && !LoadingProcess.Instance.IsLoadingInProcess
                        ? StepStatus.Done : StepStatus.Running;

                case "answer":
                    return SelectAnswer(game, step.Index);

                case "advanceUntil":
                    return AdvanceDialoguesUntil(game, step);

                case "autoplayUntilControl":
                    return AutoplayUntilControl(game, step);

                case "toggleMod":
                    UnityModManager.FindMod(ProductAccess.ProductId).Active = step.Enabled;
                    recorder.Event("modToggled", step.Enabled);
                    return StepStatus.Done;

                case "armFault":
                    FaultInjection.Arm();
                    recorder.Event("faultArmed");
                    return StepStatus.Done;

                case "loadSave":
                    if (!stepBegun || double.IsNaN(conditionMetAt))
                    {
                        conditionMetAt = Now;
                        SaveInfo save = game.SaveManager.LoadZipSave(Path.Combine(game.SaveManager.SavePath, step.Save));
                        recorder.Event("loadSaveInGame", step.Save);
                        game.LoadGame(save);
                        return StepStatus.Running;
                    }

                    return Now - conditionMetAt > 1.0 && !LoadingProcess.Instance.IsLoadingInProcess && game.CurrentlyLoadedArea != null
                        ? StepStatus.Done : StepStatus.Running;

                default:
                    stepFailure = "unknown op " + step.Op;
                    return StepStatus.Failed;
            }
        }

        private StepStatus Settled(bool condition, double settleSeconds)
        {
            if (!condition)
            {
                conditionMetAt = double.NaN;
                return StepStatus.Running;
            }

            if (double.IsNaN(conditionMetAt)) conditionMetAt = Now;
            return Now - conditionMetAt >= settleSeconds ? StepStatus.Done : StepStatus.Running;
        }

        private StepStatus Fail(bool failed, string message)
        {
            if (!failed) return StepStatus.Done;
            stepFailure = message;
            return StepStatus.Failed;
        }

        /// <summary>Sends count presses (down, hold, up) spaced by intervalMs, as real OS key events.</summary>
        /// <summary>
        /// Exactly one operation started after the last skip-key mark, has finished, and (when "mode" lists reasons,
        /// separated by "|") ended for one of them. An earlier operation's report never satisfies this step.
        /// </summary>
        private StepStatus WaitSkipIdle(HarnessStep step)
        {
            int started = ProductAccess.StartedOperations - operationsAtMark;
            if (started > 1) return Fail(true, started + " operations started after the last input mark (expected one)");
            if (started == 0 || !ProductAccess.IsIdle || ProductAccess.LastReportOperationId <= operationsAtMark) return StepStatus.Running;
            string reason = ProductAccess.LastReportReason;
            bool expected = string.IsNullOrEmpty(step.Mode) || Array.IndexOf(step.Mode.Split('|'), reason) >= 0;
            return Fail(!expected, "skip ended with " + reason + ", expected " + step.Mode);
        }

        /// <summary>
        /// Gives the main character a timed buff (blueprint name in "match"; "|" separates fallbacks) lasting "seconds" of
        /// game time, so a fixture carries a real expiring timer through the skipped scene. Applied identically in normal
        /// and skipped scenarios.
        /// </summary>
        private StepStatus ApplyBuff(Game game, HarnessStep step)
        {
            string[] names = (step.Match ?? string.Empty).Split('|');
            Kingmaker.UnitLogic.Buffs.Blueprints.BlueprintBuff blueprint = null;
            foreach (string name in names)
            {
                blueprint = Kingmaker.Blueprints.ResourcesLibrary.GetBlueprints<Kingmaker.UnitLogic.Buffs.Blueprints.BlueprintBuff>()
                    .FirstOrDefault(candidate => candidate != null && string.Equals(candidate.name, name, StringComparison.Ordinal));
                if (blueprint != null) break;
            }

            if (blueprint == null) return Fail(true, "no buff blueprint named " + step.Match);
            UnitEntityData unit = game.Player.MainCharacter.Value;
            var buff = unit.Descriptor.Buffs.AddBuff(blueprint, unit, TimeSpan.FromSeconds(step.Seconds));
            if (buff == null) return Fail(true, "buff " + blueprint.name + " was not applied");
            recorder.Event("buffApplied", blueprint.name + " for " + step.Seconds.ToString(CultureInfo.InvariantCulture) +
                "s at game time " + game.Player.GameTime.TotalSeconds.ToString("0.000", CultureInfo.InvariantCulture));
            return StepStatus.Done;
        }

        private void MarkOperations(string why)
        {
            operationsAtMark = ProductAccess.StartedOperations;
            recorder.Event("operationMark", (why ?? "?") + "@" + operationsAtMark);
        }

        private StepStatus PressKey(HarnessStep step)
        {
            if (keyEventsSent == 0 && !NativeKeyboard.EnsureForeground())
            {
                stepFailure = "game window is not in the foreground; refusing to send input";
                return StepStatus.Failed;
            }

            // Only skip-key presses are input attempts that may start an operation; Escape (cancel) keeps the mark.
            if (keyEventsSent == 0 && (step.Key == "Return" || step.Key == "KeypadEnter")) MarkOperations("pressKey " + step.Key);

            double elapsedMs = (Now - stepStartedAt) * 1000.0;
            while (keyEventsSent < step.Count * 2)
            {
                int press = keyEventsSent / 2;
                bool down = keyEventsSent % 2 == 0;
                double dueMs = press * (double)Math.Max(step.IntervalMs, step.HoldMs + 30) + (down ? 0 : step.HoldMs);
                if (elapsedMs < dueMs) return StepStatus.Running;
                if (!NativeKeyboard.Send(step.Key, down))
                {
                    if (!down) NativeKeyboard.EnsureForeground();
                    stepFailure = "lost foreground while sending " + step.Key;
                    return StepStatus.Failed;
                }

                recorder.Event(down ? "keyDown" : "keyUp", step.Key);
                keyEventsSent++;
            }

            return StepStatus.Done;
        }

        /// <summary>
        /// Walks the main character toward a position with a native move command (as a click would). Completes on
        /// arrival or as soon as the game leaves ordinary play (a trigger started a cutscene or dialogue on the way).
        /// </summary>
        private StepStatus MoveMainCharacter(Game game, HarnessStep step)
        {
            if (game.CurrentMode != Kingmaker.GameModes.GameModeType.Default) return StepStatus.Done;
            UnitEntityData unit = game.Player.MainCharacter.Value;
            string[] parts = step.Position.Split(',');
            Vector3 target = new Vector3(
                float.Parse(parts[0], CultureInfo.InvariantCulture),
                float.Parse(parts[1], CultureInfo.InvariantCulture),
                float.Parse(parts[2], CultureInfo.InvariantCulture));
            if (double.IsNaN(conditionMetAt))
            {
                conditionMetAt = Now;
                unit.Commands.Run(new UnitMoveTo(target, 0.5f));
                recorder.Event("moveTo", step.Position);
            }

            Vector3 delta = unit.Position - target;
            delta.y = 0;
            return delta.magnitude < 1.0f ? StepStatus.Done : StepStatus.Running;
        }

        /// <summary>
        /// Progresses dialogues deterministically until the requested top mode appears: each step picks the first
        /// selectable answer not chosen earlier in this run (else the last one), at a fixed real-time cadence.
        /// The same rule is used for normal and skipped runs so both reach the same story branch.
        /// </summary>
        private StepStatus AdvanceDialoguesUntil(Game game, HarnessStep step)
        {
            if (string.Equals(game.CurrentMode.ToString(), step.Mode, StringComparison.Ordinal)) return StepStatus.Done;
            if (game.CurrentMode != Kingmaker.GameModes.GameModeType.Dialog || game.DialogController.Dialog == null) return StepStatus.Running;
            double interval = step.Seconds > 0 ? step.Seconds : 1.0;
            if (!double.IsNaN(conditionMetAt) && Now - conditionMetAt < interval) return StepStatus.Running;
            conditionMetAt = Now;

            BlueprintAnswer[] answers = game.DialogController.Answers.Where(answer => answer.CanSelect()).ToArray();
            if (answers.Length == 0) return StepStatus.Running;
            BlueprintAnswer choice = answers.FirstOrDefault(answer => chosenAnswers.Add(answer.AssetGuid)) ?? answers[answers.Length - 1];
            recorder.Event("answer", game.DialogController.CurrentCue?.name + " -> " + choice.name);
            game.DialogController.SelectAnswer(choice);
            return StepStatus.Running;
        }

        /// <summary>
        /// Answers dialogues with the deterministic rule and waits through cinematics until ordinary control
        /// (Default mode, no control-locking cutscene) has persisted for step.seconds.
        /// </summary>
        private StepStatus AutoplayUntilControl(Game game, HarnessStep step)
        {
            if (game.CurrentMode == Kingmaker.GameModes.GameModeType.Dialog)
            {
                controlSince = double.NaN;
                cinematicSince = double.NaN;
                HarnessStep cadence = new HarnessStep { Mode = "__never__", Seconds = 1.0 };
                AdvanceDialoguesUntil(game, cadence);
                return StepStatus.Running;
            }

            if (game.CurrentMode == Kingmaker.GameModes.GameModeType.Cutscene)
            {
                controlSince = double.NaN;
                if (double.IsNaN(cinematicSince))
                {
                    cinematicSince = Now;
                    skipPressedThisEpisode = false;
                }

                if (step.SkipAfterSeconds >= 0 && !skipPressedThisEpisode && Now - cinematicSince >= step.SkipAfterSeconds)
                {
                    skipPressedThisEpisode = true;
                    // key "direct" requests the skip through the product's API instead of a key event (labelled
                    // as such in the evidence; used only where real input is unavailable).
                    if (step.Key == "direct")
                    {
                        recorder.Event("skipDirect", ProductAccess.TryStart(out string declined) ? "started" : "declined: " + declined);
                        autoplaySkipPresses++;
                    }
                    else if (PressOnce(step.Key ?? "Return"))
                    {
                        autoplaySkipPresses++;
                    }
                    else
                    {
                        autoplaySkipRefused++;
                    }
                }

                return StepStatus.Running;
            }

            cinematicSince = double.NaN;
            bool control = game.CurrentMode == Kingmaker.GameModes.GameModeType.Default && !game.CutsceneLock;
            if (!control)
            {
                controlSince = double.NaN;
                return StepStatus.Running;
            }

            if (double.IsNaN(controlSince)) controlSince = Now;
            if (Now - controlSince < step.Seconds) return StepStatus.Running;

            // Every skip press must have started exactly one operation, and nothing else may have started one.
            int started = ProductAccess.StartedOperations - operationsAtStepBegin;
            result["autoplay_" + stepIndex] = new JObject
            {
                ["skipPresses"] = autoplaySkipPresses, ["skipPressesRefused"] = autoplaySkipRefused, ["skipsStarted"] = started
            };
            if (step.SkipAfterSeconds >= 0 && autoplaySkipRefused > 0)
            {
                return Fail(true, autoplaySkipRefused + " skip presses could not be sent (game not foreground)");
            }

            return Fail(step.SkipAfterSeconds >= 0 && ProductAccess.IsLoaded && started != autoplaySkipPresses,
                autoplaySkipPresses + " skip presses but " + started + " operations started");
        }

        /// <summary>One real key press (down now, up a few frames later), only while the game is foreground.</summary>
        private bool PressOnce(string key)
        {
            if (!NativeKeyboard.EnsureForeground() || !NativeKeyboard.Send(key, true))
            {
                recorder.Event("keyRefused", key + ": game not foreground");
                return false;
            }

            recorder.Event("keyDown", key);
            pendingKeyUp = key;
            pendingKeyUpAt = Now + 0.08;
            return true;
        }

        private bool saveCompleted;
        private string pendingKeyUp;
        private double pendingKeyUpAt;
        private double cinematicSince = double.NaN;
        private bool skipPressedThisEpisode;
        private double controlSince = double.NaN;

        private readonly System.Collections.Generic.HashSet<string> chosenAnswers = new System.Collections.Generic.HashSet<string>();

        /// <summary>Issues the native click interaction (UnitInteractWithObject) with the nearest interactable map object.</summary>
        private StepStatus InteractNearest(Game game, HarnessStep step)
        {
            UnitEntityData unit = game.Player.MainCharacter.Value;
            double radius = step.Seconds > 0 ? step.Seconds : 8.0;
            Kingmaker.View.MapObjects.InteractionComponent best = null;
            float bestDistance = float.MaxValue;
            foreach (var interaction in UnityEngine.Object.FindObjectsOfType<Kingmaker.View.MapObjects.InteractionComponent>())
            {
                if (interaction == null || !interaction.isActiveAndEnabled) continue;
                if (!string.IsNullOrEmpty(step.Match) && interaction.name.IndexOf(step.Match, StringComparison.OrdinalIgnoreCase) < 0 &&
                    interaction.GetType().Name.IndexOf(step.Match, StringComparison.OrdinalIgnoreCase) < 0) continue;
                float distance = Vector3.Distance(interaction.transform.position, unit.Position);
                if (distance < bestDistance)
                {
                    best = interaction;
                    bestDistance = distance;
                }
            }

            if (best == null || bestDistance > radius)
            {
                string nearest = string.Join("; ", UnityEngine.Object.FindObjectsOfType<Kingmaker.View.MapObjects.InteractionComponent>()
                    .OrderBy(candidate => Vector3.Distance(candidate.transform.position, unit.Position)).Take(6)
                    .Select(candidate => candidate.name + "/" + candidate.GetType().Name + "@" +
                        Vector3.Distance(candidate.transform.position, unit.Position).ToString("0.0", CultureInfo.InvariantCulture) +
                        (candidate.isActiveAndEnabled ? string.Empty : "(inactive)")).ToArray());
                stepFailure = "no interactable object within " + radius + "m; nearest: " + nearest;
                return StepStatus.Failed;
            }

            recorder.Event("interact", best.name + " (" + best.GetType().Name + ") at " + bestDistance.ToString("0.0", CultureInfo.InvariantCulture) + "m");
            unit.Commands.Run(new UnitInteractWithObject(best));
            return StepStatus.Done;
        }

        /// <summary>Uses the nearest area exit exactly as clicking its overtip does (AreaTransitionController.StartAreaTransition).</summary>
        private StepStatus UseNearestAreaTransition(Game game)
        {
            UnitEntityData unit = game.Player.MainCharacter.Value;
            Kingmaker.View.MapObjects.AreaTransition exit = UnityEngine.Object.FindObjectsOfType<Kingmaker.View.MapObjects.AreaTransition>()
                .Where(candidate => candidate != null && candidate.isActiveAndEnabled)
                .OrderBy(candidate => Vector3.Distance(candidate.transform.position, unit.Position))
                .FirstOrDefault();
            if (exit == null)
            {
                stepFailure = "no area transition in the scene";
                return StepStatus.Failed;
            }

            var units = game.Player.GetPartyCharactersForGroupCommand(exit.transform.position, true);
            var group = new Kingmaker.UnitLogic.Commands.AreaTransitionGroupCommand(units, exit);
            Vector3 point = Kingmaker.View.ObstacleAnalyzer.GetDeepNavmeshPoint(exit.transform.position, 1.5f);
            foreach (UnitEntityData member in units)
            {
                Kingmaker.UI.MapObjectOvertip.AreaTransitionController.RunUnitTransitionCommand(group, member, point, null);
            }

            recorder.Event("areaTransition", exit.name + " at " + Vector3.Distance(exit.transform.position, unit.Position).ToString("0.0", CultureInfo.InvariantCulture) + "m");
            return StepStatus.Done;
        }

        private StepStatus SelectAnswer(Game game, int index)
        {
            BlueprintAnswer[] answers = game.DialogController.Answers.ToArray();
            if (game.DialogController.Dialog == null || index >= answers.Length)
            {
                stepFailure = "no dialogue answer " + index;
                return StepStatus.Failed;
            }

            recorder.Event("answer", answers[index].name);
            game.DialogController.SelectAnswer(answers[index]);
            return StepStatus.Done;
        }

        private static bool HasControllingCutscene(string match)
        {
            return Game.Instance.State.Cutscenes.ToList().Any(player =>
                player != null && !player.IsFinished && !player.Destroyed && player.Exclusive && !player.Paused &&
                (string.IsNullOrEmpty(match) || (player.Cutscene != null && player.Cutscene.name.IndexOf(match, StringComparison.OrdinalIgnoreCase) >= 0)));
        }

        private void WriteSnapshot(string label)
        {
            recorder.WriteJson("snapshot-" + label + ".json", StateSnapshot.Capture(label));
        }

        private void SubscribeToSkipReports()
        {
            ProductAccess.SubscribeReports(report => recorder.Event("skipEnded", report));
        }

        private string CurrentStepName()
        {
            return stage == Stage.Steps && stepIndex < request.Steps.Count ? request.Steps[stepIndex].ToString() : stage.ToString();
        }

        private void Enter(Stage next)
        {
            stage = next;
            stageStartedAt = Now;
            recorder.Event("stage", next.ToString());
        }

        public void Finish(bool passed, string failure)
        {
            if (stage == Stage.Finished) return;
            stage = Stage.Finished;
            result["status"] = passed ? "passed" : "failed";
            result["failure"] = failure;
            result["stepsCompleted"] = stepIndex;
            result["framesCaptured"] = recorder.FramesCaptured;
            result["finishedRealtime"] = Now;
            result["lastSkipReport"] = ProductAccess.LastReportJson;
            recorder.Event("finished", passed ? "passed" : "failed: " + failure);
            recorder.Flush();
            recorder.WriteJson("runtime-result.json", result);
            EventBus.Unsubscribe(recorder);
            if (request.ExitAfterCompletion) quitCountdown = 30;
        }
    }
}
